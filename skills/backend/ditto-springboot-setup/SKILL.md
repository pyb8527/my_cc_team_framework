---
name: ditto-springboot-setup
description: Spring Boot 3.3 프로젝트 초기 세팅 스킬. Ditto 프로젝트 아키텍처 기반의 헥사고날 멀티모듈 구조(core-app/core-business/storage-jpa/support-*), JWT 인증, MySQL JPA, MDC 트레이싱, GlobalExceptionHandler, ApiResponse 래퍼, OpenAPI 설정까지 완전한 프로젝트 골격을 생성한다.
---

# Spring Boot 3.3 — Ditto 아키텍처 기반 초기 세팅

## 아키텍처 개요

```
┌──────────────────────────────────────┐
│  core-app  (Controller, Payload)     │  ← Spring MVC, Security, Swagger
└───────────────┬──────────────────────┘
                │ depends on
                ▼
┌──────────────────────────────────────┐
│  core-business  (Domain, Service)   │  ← 순수 비즈니스 로직, Port 인터페이스
│  No Spring Web dependency           │
└──────┬───────────────────────────────┘
       │ implements ports
       ▼
┌──────────────────────┐  ┌─────────────────────┐
│  storage-jpa         │  │  support-security   │
│  (JPA Adapter)       │  │  (JWT, BCrypt)      │
└──────────────────────┘  └─────────────────────┘
       ┌─────────────────────┐  ┌──────────────────┐
       │  support-log        │  │  support-monitoring│
       │  (MDC Trace)        │  │  (OpenAPI)        │
       └─────────────────────┘  └──────────────────┘
```

**핵심 설계 원칙:**
- Service는 구체 클래스(`@Service`) — 인터페이스 없음
- Port 인터페이스는 `core-business`에 정의, 구현체는 `storage-*` / `support-*`
- `ErrorCode`는 `int httpStatusCode` 사용 (Spring `HttpStatus` 미사용 → 도메인 순수성 유지)
- 모든 엔티티는 `BaseEntity` 상속 → `createdAt`, `updatedAt` 자동 관리

---

## 1단계: Gradle 멀티모듈 구조 생성

### settings.gradle
```groovy
rootProject.name = '{project-name}'

include 'client'
include 'core:core-app'
include 'core:core-business'
include 'storage:storage-jpa'
include 'support:support-security'
include 'support:support-log'
include 'support:support-monitoring'
include 'support:support-util'
```

### 루트 build.gradle
```groovy
plugins {
    id 'org.springframework.boot' version '3.3.6' apply false
    id 'io.spring.dependency-management' version '1.1.6' apply false
}

allprojects {
    group = 'com.{project}'
    version = '0.0.1-SNAPSHOT'
    repositories { mavenCentral() }
}

subprojects {
    apply plugin: 'java-library'
    apply plugin: 'io.spring.dependency-management'

    java {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    dependencyManagement {
        imports {
            mavenBom "org.springframework.boot:spring-boot-dependencies:3.3.6"
        }
    }

    dependencies {
        testImplementation 'org.springframework.boot:spring-boot-starter-test'
    }

    tasks.named('test') { useJUnitPlatform() }

    tasks.withType(JavaCompile).configureEach {
        options.encoding = 'UTF-8'
    }
}
```

### 모듈별 build.gradle

#### core/core-app/build.gradle
```groovy
plugins { id 'org.springframework.boot' }

tasks.named('jar') { enabled = false }

dependencies {
    implementation project(':core:core-business')
    implementation project(':storage:storage-jpa')
    implementation project(':support:support-util')
    implementation project(':support:support-log')
    implementation project(':support:support-monitoring')
    implementation project(':support:support-security')

    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-security'
    implementation 'org.springframework.boot:spring-boot-starter-validation'
    implementation 'org.springframework.data:spring-data-commons'
    implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.6.0'

    compileOnly 'org.projectlombok:lombok'
    annotationProcessor 'org.projectlombok:lombok'
}
```

#### core/core-business/build.gradle
```groovy
plugins { id 'java-test-fixtures' }

dependencies {
    implementation 'org.springframework:spring-context'
    implementation 'org.springframework:spring-tx'
    implementation 'org.springframework.data:spring-data-commons'

    compileOnly 'org.projectlombok:lombok'
    annotationProcessor 'org.projectlombok:lombok'
    testFixturesCompileOnly 'org.projectlombok:lombok'
    testFixturesAnnotationProcessor 'org.projectlombok:lombok'
}
```

#### storage/storage-jpa/build.gradle
```groovy
dependencies {
    implementation project(':core:core-business')
    implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
    runtimeOnly 'com.mysql:mysql-connector-j'

    compileOnly 'org.projectlombok:lombok'
    annotationProcessor 'org.projectlombok:lombok'
}
```

#### support/support-security/build.gradle
```groovy
dependencies {
    implementation project(':core:core-business')
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-security'

    implementation 'io.jsonwebtoken:jjwt-api:0.12.6'
    runtimeOnly 'io.jsonwebtoken:jjwt-impl:0.12.6'
    runtimeOnly 'io.jsonwebtoken:jjwt-jackson:0.12.6'

    compileOnly 'org.projectlombok:lombok'
    annotationProcessor 'org.projectlombok:lombok'
}
```

#### support/support-log, support-monitoring, support-util, client
```groovy
// support-log, support-monitoring, support-util
dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    compileOnly 'org.projectlombok:lombok'
    annotationProcessor 'org.projectlombok:lombok'
}

// client
dependencies {
    implementation project(':core:core-business')
    implementation 'org.springframework.boot:spring-boot-starter-web'
    compileOnly 'org.projectlombok:lombok'
    annotationProcessor 'org.projectlombok:lombok'
}
```

---

## 2단계: 애플리케이션 진입점

```java
// core/core-app/src/main/java/com/{project}/{ProjectName}Application.java
package com.{project};

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class {ProjectName}Application {
    public static void main(String[] args) {
        SpringApplication.run({ProjectName}Application.class, args);
    }
}
```

---

## 3단계: 설정 파일

### core/core-app/src/main/resources/application.yml
```yaml
spring:
  application:
    name: {project-name}
  config:
    import: classpath:storage-db.yml

  jackson:
    default-property-inclusion: non_null
    serialization:
      write-dates-as-timestamps: false

  servlet:
    multipart:
      max-file-size: 10MB
      max-request-size: 10MB

server:
  port: 8080

springdoc:
  swagger-ui:
    path: /swagger-ui.html
    tags-sorter: alpha
    operations-sorter: alpha
  api-docs:
    path: /v3/api-docs
  default-consumes-media-type: application/json
  default-produces-media-type: application/json

jwt:
  secret: ${JWT_SECRET:base64-encoded-secret-min-256bits}
  access-expiry: ${JWT_ACCESS_EXPIRY:3600000}     # 1시간
  refresh-expiry: ${JWT_REFRESH_EXPIRY:604800000}  # 7일

app:
  cors-allowed-origins: ${CORS_ALLOWED_ORIGINS:http://localhost:3000}

logging:
  level:
    com.{project}: DEBUG
    org.hibernate.SQL: DEBUG
    org.hibernate.orm.jdbc.bind: TRACE
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} [%thread] [%X{traceId}] %-5level %logger{36} - %msg%n"
```

### core/core-app/src/main/resources/application-prod.yml
```yaml
logging:
  level:
    com.{project}: INFO
    org.hibernate.SQL: WARN
    org.hibernate.orm.jdbc.bind: WARN
```

### storage/storage-jpa/src/main/resources/storage-db.yml
```yaml
spring:
  datasource:
    url: ${DB_URL:jdbc:mysql://localhost:3306/{project}?useSSL=false&serverTimezone=Asia/Seoul&allowPublicKeyRetrieval=true}
    driver-class-name: com.mysql.cj.jdbc.Driver
    username: ${DB_USERNAME:root}
    password: ${DB_PASSWORD:1234}

  jpa:
    hibernate:
      ddl-auto: ${DDL_AUTO:update}
    show-sql: false
    properties:
      hibernate:
        format_sql: true
        default_batch_fetch_size: 100
        dialect: org.hibernate.dialect.MySQLDialect
    open-in-view: false
```

---

## 4단계: 도메인 공통 코드 (core-business)

### ErrorCode
```java
package com.{project}.core.business.common.exception;

public enum ErrorCode {
    INVALID_INPUT(400, "INVALID_INPUT", "입력값이 유효하지 않습니다."),
    UNAUTHORIZED(401, "UNAUTHORIZED", "인증이 필요합니다."),
    FORBIDDEN(403, "FORBIDDEN", "접근 권한이 없습니다."),
    ENTITY_NOT_FOUND(404, "ENTITY_NOT_FOUND", "요청한 리소스를 찾을 수 없습니다."),
    DUPLICATE_RESOURCE(409, "DUPLICATE_RESOURCE", "리소스가 이미 존재합니다."),
    INTERNAL_ERROR(500, "INTERNAL_ERROR", "서버 내부 오류가 발생했습니다.");

    private final int httpStatusCode;
    private final String code;
    private final String message;

    ErrorCode(int httpStatusCode, String code, String message) {
        this.httpStatusCode = httpStatusCode;
        this.code = code;
        this.message = message;
    }

    public int getHttpStatusCode() { return httpStatusCode; }
    public String getCode() { return code; }
    public String getMessage() { return message; }
}
```

### BusinessException
```java
package com.{project}.core.business.common.exception;

public abstract class BusinessException extends RuntimeException {
    private final ErrorCode errorCode;

    protected BusinessException(ErrorCode errorCode) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
    }

    protected BusinessException(ErrorCode errorCode, String detailMessage) {
        super(detailMessage);
        this.errorCode = errorCode;
    }

    public ErrorCode getErrorCode() { return errorCode; }
}
```

### UserRole
```java
package com.{project}.core.business.user.domain;

public enum UserRole {
    USER, ADMIN
}
```

---

## 5단계: 응답 래퍼 (core-app)

### ApiResponse
```java
package com.{project}.core.app.common.response;

public class ApiResponse<T> {
    private final boolean success;
    private final T data;
    private final String message;

    private ApiResponse(boolean success, T data, String message) {
        this.success = success;
        this.data = data;
        this.message = message;
    }

    public static <T> ApiResponse<T> success(T data) {
        return new ApiResponse<>(true, data, null);
    }

    public static <T> ApiResponse<T> success() {
        return new ApiResponse<>(true, null, null);
    }

    public static <T> ApiResponse<T> error(String message) {
        return new ApiResponse<>(false, null, message);
    }

    public boolean isSuccess() { return success; }
    public T getData() { return data; }
    public String getMessage() { return message; }
}
```

### ErrorResponse
```java
package com.{project}.core.app.common.response;

import java.time.LocalDateTime;
import java.util.List;

public record ErrorResponse(
        String code,
        String message,
        List<FieldError> errors,
        LocalDateTime timestamp
) {
    public static ErrorResponse of(BusinessException e) {
        return new ErrorResponse(e.getErrorCode().getCode(), e.getMessage(), List.of(), LocalDateTime.now());
    }

    public static ErrorResponse of(ErrorCode errorCode, List<FieldError> fieldErrors) {
        return new ErrorResponse(errorCode.getCode(), errorCode.getMessage(), fieldErrors, LocalDateTime.now());
    }

    public record FieldError(String field, String value, String reason) {}
}
```

### GlobalExceptionHandler
```java
package com.{project}.core.app.common.config;

@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ErrorResponse> handleBusinessException(BusinessException e) {
        log.warn("Business exception | code={} message={}", e.getErrorCode().getCode(), e.getMessage());
        return ResponseEntity.status(e.getErrorCode().getHttpStatusCode()).body(ErrorResponse.of(e));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException e) {
        List<ErrorResponse.FieldError> fieldErrors = e.getBindingResult().getFieldErrors().stream()
                .map(err -> new ErrorResponse.FieldError(
                        err.getField(),
                        err.getRejectedValue() != null ? err.getRejectedValue().toString() : "",
                        err.getDefaultMessage()))
                .toList();
        log.warn("Validation failed | errors={}", fieldErrors);
        return ResponseEntity.badRequest().body(ErrorResponse.of(ErrorCode.INVALID_INPUT, fieldErrors));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleUnexpected(Exception e) {
        log.error("Unexpected server error", e);
        return ResponseEntity.status(500).body(ErrorResponse.of(ErrorCode.INTERNAL_ERROR, List.of()));
    }
}
```

---

## 6단계: Spring Security + JWT (support-security)

### JwtProperties
```java
@ConfigurationProperties(prefix = "jwt")
public record JwtProperties(String secret, long accessExpiry, long refreshExpiry) {}
```

### JwtService
```java
@Service
@RequiredArgsConstructor
public class JwtService {
    private final JwtProperties jwtProperties;

    public String generateAccessToken(Long userId, UserRole role) {
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim("role", role.name())
                .claim("type", "access")
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + jwtProperties.accessExpiry()))
                .signWith(getSigningKey())
                .compact();
    }

    public String generateRefreshToken(Long userId) {
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim("type", "refresh")
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + jwtProperties.refreshExpiry()))
                .signWith(getSigningKey())
                .compact();
    }

    public Claims parseToken(String token) {
        return Jwts.parser().verifyWith(getSigningKey()).build()
                .parseSignedClaims(token).getPayload();
    }

    public boolean validateToken(String token) {
        try { parseToken(token); return true; }
        catch (JwtException | IllegalArgumentException e) { return false; }
    }

    private SecretKey getSigningKey() {
        return Keys.hmacShaKeyFor(Decoders.BASE64.decode(jwtProperties.secret()));
    }
}
```

### UserPrincipal
```java
public class UserPrincipal implements UserDetails {
    private final Long userId;
    private final UserRole role;

    public UserPrincipal(Long userId, UserRole role) {
        this.userId = userId;
        this.role = role;
    }

    public Long getUserId() { return userId; }
    public UserRole getRole() { return role; }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_" + role.name()));
    }

    @Override public String getPassword() { return null; }
    @Override public String getUsername() { return String.valueOf(userId); }
}
```

### SecurityConfig
```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
@EnableConfigurationProperties({JwtProperties.class})
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final CustomAuthenticationEntryPoint authenticationEntryPoint;
    private final CustomAccessDeniedHandler accessDeniedHandler;

    @Value("${app.cors-allowed-origins:http://localhost:3000}")
    private String corsAllowedOrigins;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
                .csrf(csrf -> csrf.disable())
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(
                                "/api/v1/auth/**",
                                "/swagger-ui/**", "/swagger-ui.html", "/v3/api-docs/**"
                        ).permitAll()
                        .anyRequest().authenticated())
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint(authenticationEntryPoint)
                        .accessDeniedHandler(accessDeniedHandler))
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
                .build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(Arrays.asList(corsAllowedOrigins.split(",")));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
```

---

## 7단계: JPA 기반 코드 (storage-jpa)

### JpaConfig
```java
@Configuration
@EnableJpaAuditing
public class JpaConfig {}
```

### BaseEntity
```java
@Getter
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity {
    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    private LocalDateTime updatedAt;
}
```

### 도메인 엔티티 템플릿
```java
@Entity
@Table(name = "users")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserEntity extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 255)
    private String email;

    @Column(nullable = false, length = 100)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private UserRole role;

    public static UserEntity create(String email, String name) {
        UserEntity entity = new UserEntity();
        entity.email = email;
        entity.name = name;
        entity.role = UserRole.USER;
        return entity;
    }
}
```

---

## 8단계: 크로스 커팅 (support-log, support-monitoring)

### MdcTraceFilter
```java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class MdcTraceFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String traceId = Optional.ofNullable(req.getHeader("X-Trace-Id"))
                .orElse(UUID.randomUUID().toString());
        try {
            MDC.put("traceId", traceId);
            res.setHeader("X-Trace-Id", traceId);
            chain.doFilter(req, res);
        } finally {
            MDC.clear();
        }
    }
}
```

### OpenApiConfig
```java
@Configuration
public class OpenApiConfig {
    @Bean
    public OpenAPI openAPI() {
        return new OpenAPI()
                .info(new Info().title("{ProjectName} API").version("v1.0"))
                .addSecurityItem(new SecurityRequirement().addList("bearerAuth"))
                .components(new Components().addSecuritySchemes("bearerAuth",
                        new SecurityScheme().type(SecurityScheme.Type.HTTP)
                                .scheme("bearer").bearerFormat("JWT")));
    }
}
```

---

## 9단계: .env.example

```bash
# .env.example
DB_URL=jdbc:mysql://localhost:3306/{project}?useSSL=false&serverTimezone=Asia/Seoul&allowPublicKeyRetrieval=true
DB_USERNAME=root
DB_PASSWORD=

JWT_SECRET=
JWT_ACCESS_EXPIRY=3600000
JWT_REFRESH_EXPIRY=604800000

CORS_ALLOWED_ORIGINS=http://localhost:3000
```

---

## 도메인 추가 시 체크리스트

새 도메인 `{domain}` 추가 시:
- [ ] `core-business/{domain}/domain/` — 도메인 객체
- [ ] `core-business/{domain}/exception/` — 도메인 예외 (`BusinessException` 상속)
- [ ] `core-business/{domain}/port/` — Port 인터페이스 (`{Domain}Reader`, `{Domain}Appender`)
- [ ] `core-business/{domain}/service/` — 서비스 구체 클래스 (`@Service`, 인터페이스 없음)
- [ ] `storage-jpa/{domain}/entity/` — JPA 엔티티 (`BaseEntity` 상속)
- [ ] `storage-jpa/{domain}/repository/` — `JpaRepository` 인터페이스
- [ ] `storage-jpa/{domain}/adapter/` — Port 구현체 (`@Component`)
- [ ] `storage-jpa/{domain}/mapper/` — Entity ↔ Domain 변환
- [ ] `core-app/{domain}/controller/` — `@RestController`
- [ ] `core-app/{domain}/payload/request/` — 요청 DTO
- [ ] `core-app/{domain}/payload/response/` — 응답 DTO
- [ ] ErrorCode에 도메인 에러 추가

---

## 빌드 & 실행

```bash
# 컴파일
JAVA_HOME="C:\\Program Files\\Java\\jdk-17" ./gradlew compileJava --no-daemon

# 실행
JAVA_HOME="C:\\Program Files\\Java\\jdk-17" ./gradlew :client:bootRun

# Swagger UI
http://localhost:8080/swagger-ui/index.html
```
