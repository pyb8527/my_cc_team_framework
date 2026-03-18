---
name: secrets-management
description: Secrets management best practices for Spring Boot and Node.js applications. Covers environment variables, AWS Secrets Manager, HashiCorp Vault, .env patterns, secret rotation, and preventing secret leakage.
---

# Secrets Management Best Practices

## What Counts as a Secret

```
Secrets (NEVER in source code):
  - Database passwords
  - JWT signing keys
  - API keys (third-party services)
  - OAuth client secrets
  - Encryption keys
  - Service account credentials

Safe to commit:
  - Public API endpoints (non-auth)
  - Feature flags (non-sensitive)
  - Log levels
  - Port numbers
  - Timeout values
```

## Local Development — .env Pattern

```bash
# .env.example  ← COMMIT THIS (template with no values)
DB_PASSWORD=
JWT_SECRET=
GOOGLE_CLIENT_ID=
AWS_ACCESS_KEY_ID=
SMTP_PASSWORD=

# .env  ← NEVER COMMIT THIS
DB_PASSWORD=local-dev-password
JWT_SECRET=local-dev-secret-min-32-chars-long
GOOGLE_CLIENT_ID=real-client-id.apps.googleusercontent.com
```

```bash
# .gitignore — always include
.env
.env.local
.env.production
*.env
```

### Spring Boot — load from .env
```java
// build.gradle
implementation 'me.paulschwarz:spring-dotenv:4.0.0'

// Then access via @Value or application.yml ${VAR_NAME} syntax
```

## AWS Secrets Manager (Production)

```java
// build.gradle
implementation 'io.awspring.cloud:spring-cloud-aws-secrets-manager-config:3.1.0'

// application.yml
spring:
  config:
    import: aws-secretsmanager:/myapp/production/db,/myapp/production/jwt
  cloud:
    aws:
      region:
        static: ap-northeast-2
      credentials:
        # Use IAM role — NOT access keys in config
        use-default-aws-credentials-chain: true
```

```java
// Programmatic access
@Service
@RequiredArgsConstructor
public class SecretService {

    private final SecretsManagerClient secretsManager;

    public String getSecret(String secretName) {
        GetSecretValueRequest request = GetSecretValueRequest.builder()
                .secretId(secretName)
                .build();
        return secretsManager.getSecretValue(request).secretString();
    }
}
```

```bash
# AWS CLI — create/update secrets
aws secretsmanager create-secret \
  --name /myapp/production/db \
  --secret-string '{"password":"super-secret","username":"appuser"}'

# Rotate secret
aws secretsmanager rotate-secret \
  --secret-id /myapp/production/db \
  --rotation-lambda-arn arn:aws:lambda:...
```

## GitHub Actions — Secrets

```yaml
# Store in GitHub Settings → Secrets and Variables → Actions
# Access in workflows:
env:
  DB_PASSWORD: ${{ secrets.PROD_DB_PASSWORD }}
  JWT_SECRET: ${{ secrets.JWT_SECRET }}

# For organization-wide secrets, use environment secrets with protection rules
jobs:
  deploy:
    environment: production   # requires reviewer approval
    env:
      API_KEY: ${{ secrets.PROD_API_KEY }}
```

## Node.js — dotenv

```typescript
// Load at app entry point (before any other imports)
import 'dotenv/config';

// Or with validation (recommended)
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  GOOGLE_CLIENT_ID: z.string(),
});

// Throws at startup if required env vars are missing
export const env = envSchema.parse(process.env);

// Usage — import env instead of process.env directly
import { env } from './config/env';
db.connect(env.DATABASE_URL);
```

## Detecting Secret Leaks

### Pre-commit Hook (gitleaks)
```bash
# Install
brew install gitleaks

# Scan repo for committed secrets
gitleaks detect --source . --verbose

# Pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/sh
gitleaks protect --staged --verbose
EOF
chmod +x .git/hooks/pre-commit
```

### GitHub Actions Scanning
```yaml
- name: Scan for secrets
  uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Vault (HashiCorp)

```java
// Spring Cloud Vault
implementation 'org.springframework.cloud:spring-cloud-starter-vault-config'

// bootstrap.yml
spring:
  cloud:
    vault:
      host: vault.internal
      port: 8200
      scheme: https
      authentication: KUBERNETES   # Use K8s service account in K8s
      kubernetes:
        role: myapp
      kv:
        enabled: true
        default-context: myapp
        backend: secret
```

## Secret Rotation Checklist

```
Rotation schedule:
  - JWT signing keys    → Every 90 days (with overlap period)
  - DB passwords        → Every 90 days (use zero-downtime rotation)
  - API keys            → On team member departure + every 180 days
  - OAuth secrets       → Every 180 days

Zero-downtime JWT rotation:
  1. Generate new signing key
  2. Add to list of valid keys (accept both old + new)
  3. Issue new tokens with new key
  4. Wait for old tokens to expire (= access token TTL)
  5. Remove old key from valid list
```

## Anti-Patterns

```bash
# ❌ Secret in application.yml committed to git
jwt:
  secret: my-actual-secret-key-123

# ✅ Reference environment variable
jwt:
  secret: ${JWT_SECRET}

# ❌ Secret in Dockerfile
ENV DB_PASSWORD=hardcoded-password

# ✅ Pass at runtime
docker run -e DB_PASSWORD=$DB_PASSWORD myapp

# ❌ Secret in CI logs
run: echo "Testing with password: $DB_PASSWORD"

# ✅ Secrets are auto-masked in GitHub Actions — but still avoid echoing them
```
