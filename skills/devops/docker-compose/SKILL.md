---
name: docker-compose
description: Docker and Docker Compose best practices for local development environments, multi-service orchestration, Spring Boot + MySQL + Redis setups, and production-ready Dockerfile patterns.
---

# Docker & Docker Compose Best Practices

## Production-Ready Dockerfile (Spring Boot)

```dockerfile
# Multi-stage build
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app
COPY gradlew settings.gradle build.gradle ./
COPY gradle ./gradle
# Cache dependencies layer
RUN ./gradlew dependencies --no-daemon || true

COPY . .
RUN ./gradlew bootJar --no-daemon -x test

# Runtime image — minimal
FROM eclipse-temurin:17-jre-alpine AS runtime
WORKDIR /app

# Non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copy only the jar
COPY --from=builder /app/build/libs/*.jar app.jar

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]
```

## Docker Compose — Full Stack (Spring Boot + MySQL + Redis)

```yaml
# docker-compose.yml
version: '3.9'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: myapp
    ports:
      - "8080:8080"
    environment:
      SPRING_PROFILES_ACTIVE: docker
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/mydb?useSSL=false&serverTimezone=Asia/Seoul&allowPublicKeyRetrieval=true
      SPRING_DATASOURCE_USERNAME: ${DB_USERNAME:-root}
      SPRING_DATASOURCE_PASSWORD: ${DB_PASSWORD:-secret}
      SPRING_DATA_REDIS_HOST: redis
      SPRING_DATA_REDIS_PORT: 6379
      JWT_SECRET: ${JWT_SECRET}
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - backend
    restart: unless-stopped

  mysql:
    image: mysql:8.0
    container_name: myapp-mysql
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_PASSWORD:-secret}
      MYSQL_DATABASE: mydb
      MYSQL_CHARACTER_SET_SERVER: utf8mb4
      MYSQL_COLLATION_SERVER: utf8mb4_unicode_ci
    volumes:
      - mysql-data:/var/lib/mysql
      - ./docker/mysql/init:/docker-entrypoint-initdb.d  # init SQL scripts
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${DB_PASSWORD:-secret}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backend

  redis:
    image: redis:7-alpine
    container_name: myapp-redis
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD:-}
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backend

volumes:
  mysql-data:
  redis-data:

networks:
  backend:
    driver: bridge
```

## Docker Compose Override (Local Dev)

```yaml
# docker-compose.override.yml — automatically merged in dev
version: '3.9'

services:
  app:
    build:
      target: builder       # Stop at builder stage (faster)
    volumes:
      - ./build/libs:/app/build/libs  # Hot reload jar
    environment:
      SPRING_PROFILES_ACTIVE: local
      LOGGING_LEVEL_COM_EXAMPLE: DEBUG

  mysql:
    ports:
      - "3307:3306"         # Expose on different port to avoid conflicts
```

## .env Template

```bash
# .env.example
DB_USERNAME=root
DB_PASSWORD=secret
REDIS_PASSWORD=
JWT_SECRET=change-me-in-production-must-be-at-least-256-bits
CORS_ALLOWED_ORIGINS=http://localhost:3000
```

## Dockerfile (Node.js / Next.js)

```dockerfile
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN yarn build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
```

## Common Commands

```bash
# Start all services
docker compose up -d

# Rebuild and start
docker compose up -d --build

# View logs
docker compose logs -f app

# Execute command in container
docker compose exec app sh

# Stop all services
docker compose down

# Remove volumes (reset DB)
docker compose down -v

# Scale service
docker compose up -d --scale worker=3
```

## Best Practices

- **Never** put secrets in Dockerfile or docker-compose.yml — use `.env` files or secrets managers
- Use specific image tags (`mysql:8.0`) — never `latest` in production
- Add `HEALTHCHECK` to every service; use `depends_on: condition: service_healthy`
- Use multi-stage builds to minimize final image size
- Run as non-root user in production images
- Mount `node_modules` as anonymous volume in dev to prevent host overwrite
- Use `.dockerignore` to exclude `node_modules`, `.git`, `target/`, `build/`
- Set `restart: unless-stopped` for production services
