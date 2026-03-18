---
name: owasp-security-checklist
description: OWASP Top 10 security checklist for Spring Boot and Node.js APIs. Covers injection prevention, broken authentication, XSS, CSRF, security misconfiguration, and secure coding patterns.
---

# OWASP Top 10 Security Checklist

## A01 — Broken Access Control

```java
// ❌ Missing authorization check
@GetMapping("/users/{id}/orders")
public List<Order> getOrders(@PathVariable Long id) {
    return orderService.findByUserId(id);  // Any logged-in user can access any user's orders!
}

// ✅ Check ownership
@GetMapping("/users/{id}/orders")
public List<Order> getOrders(@PathVariable Long id,
                              @AuthenticationPrincipal UserPrincipal principal) {
    if (!principal.getUserId().equals(id) && !principal.getRole().equals(UserRole.ADMIN)) {
        throw new ForbiddenException();
    }
    return orderService.findByUserId(id);
}

// ✅ Or use method security
@PreAuthorize("#id == authentication.principal.userId or hasRole('ADMIN')")
@GetMapping("/users/{id}/orders")
public List<Order> getOrders(@PathVariable Long id) { ... }
```

## A02 — Cryptographic Failures

```java
// ❌ Never store plaintext passwords
user.setPassword(rawPassword);

// ❌ Never use MD5/SHA1 for passwords
MessageDigest.getInstance("MD5").digest(password.getBytes());

// ✅ Use BCrypt (Spring Security)
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);  // cost factor 12
}

// ❌ Never log sensitive data
log.info("User {} logged in with password {}", email, password);

// ✅ Log only non-sensitive identifiers
log.info("User {} authenticated successfully", userId);

// ✅ Enforce HTTPS — redirect HTTP to HTTPS
http.requiresChannel(channel -> channel.anyRequest().requiresSecure());
```

## A03 — Injection

```java
// ❌ SQL Injection
String query = "SELECT * FROM users WHERE email = '" + email + "'";
jdbcTemplate.query(query, ...);

// ✅ Parameterized query
jdbcTemplate.query("SELECT * FROM users WHERE email = ?", new Object[]{email}, mapper);

// ✅ JPA/Hibernate (auto-parameterized)
userRepository.findByEmail(email);

// ❌ JPQL injection
entityManager.createQuery("FROM User WHERE name = '" + name + "'");

// ✅ JPQL named parameter
entityManager.createQuery("FROM User WHERE name = :name")
    .setParameter("name", name);

// ❌ OS Command injection (Node.js)
exec(`convert ${userInput} output.jpg`);

// ✅ Use library with argument array
execFile('convert', [userInput, 'output.jpg']);
```

## A04 — Insecure Design

```
Checklist:
- [ ] Threat model documented for each feature
- [ ] Rate limiting on auth endpoints
- [ ] Account lockout after N failed attempts
- [ ] Email verification before account activation
- [ ] Sensitive operations require re-authentication
- [ ] Business logic enforced server-side (never client-side only)
```

## A05 — Security Misconfiguration

```yaml
# application-production.yml

# ❌ Never in production
spring:
  jpa:
    show-sql: true
  h2:
    console:
      enabled: true

# ✅ Production settings
spring:
  jpa:
    show-sql: false
  h2:
    console:
      enabled: false

management:
  endpoints:
    web:
      exposure:
        include: health,info   # NOT * (never expose all actuator endpoints)
  endpoint:
    health:
      show-details: never      # Don't leak stack traces
```

```java
// ✅ Security headers
http.headers(headers -> headers
    .contentSecurityPolicy(csp -> csp.policyDirectives("default-src 'self'"))
    .xssProtection(xss -> xss.headerValue(XXssProtectionHeaderWriter.HeaderValue.ENABLED_MODE_BLOCK))
    .frameOptions(frame -> frame.deny())
    .httpStrictTransportSecurity(hsts -> hsts.includeSubDomains(true).maxAgeInSeconds(31536000))
);
```

## A06 — Vulnerable Components

```bash
# Check for vulnerable dependencies
./gradlew dependencyCheckAnalyze   # OWASP Dependency-Check (Gradle)
npm audit --audit-level=high       # npm
pip install safety && safety check # Python

# GitHub Actions — auto-scan
- uses: actions/dependency-review-action@v4
  if: github.event_name == 'pull_request'
```

## A07 — Identification & Authentication Failures

```java
// ✅ JWT best practices
// - Short access token expiry (15min-1h)
// - Rotate refresh tokens on use
// - Invalidate refresh tokens on logout
// - Use secure + httpOnly cookies for refresh tokens

// ✅ Rate limit auth endpoints
@RateLimiter(name = "auth", fallbackMethod = "rateLimitFallback")
@PostMapping("/auth/login")
public ResponseEntity<LoginResponse> login(@RequestBody LoginRequest request) { ... }

// ✅ Timing-safe password comparison (BCrypt does this automatically)
passwordEncoder.matches(rawPassword, encodedPassword);
// Don't write your own string comparison for passwords
```

## A08 — Software & Data Integrity Failures

```yaml
# Verify dependency integrity
# build.gradle — use dependency verification
# Generate: ./gradlew --write-verification-metadata sha256
dependencyVerification {
    verifyConfiguration = true
}

# CI: verify Docker image signatures
- name: Verify image
  run: cosign verify --certificate-identity=... registry/myapp:latest
```

## A09 — Logging & Monitoring Failures

```java
// ✅ Log security events (not passwords/tokens)
log.warn("Failed login attempt | email={} ip={}", email, request.getRemoteAddr());
log.warn("Access denied | userId={} resource={}", userId, resource);
log.info("Password changed | userId={}", userId);
log.error("Unexpected error | traceId={}", MDC.get("traceId"), exception);

// ✅ Never log:
// - Passwords
// - JWT tokens
// - Credit card numbers
// - PII in production
```

## A10 — Server-Side Request Forgery (SSRF)

```java
// ❌ Fetch user-supplied URL directly
RestTemplate rt = new RestTemplate();
rt.getForObject(userSuppliedUrl, String.class);

// ✅ Allowlist permitted domains
private static final Set<String> ALLOWED_HOSTS = Set.of("api.trusted.com", "cdn.trusted.com");

URI uri = URI.create(userSuppliedUrl);
if (!ALLOWED_HOSTS.contains(uri.getHost())) {
    throw new ForbiddenException("URL not allowed: " + uri.getHost());
}
```

## Quick Checklist

```
Auth & Access
- [ ] All endpoints require authentication (unless explicitly public)
- [ ] Authorization checked for resource ownership
- [ ] JWT secret is strong (256-bit+), stored in env var
- [ ] Refresh token rotation implemented
- [ ] Rate limiting on /auth/** endpoints

Input & Output
- [ ] All user input validated (Bean Validation)
- [ ] SQL queries use parameterized statements
- [ ] File uploads: type whitelist, size limit, stored outside webroot
- [ ] No sensitive data in URLs (use body/headers)

Config
- [ ] Swagger disabled in production
- [ ] Actuator endpoints restricted
- [ ] HTTPS enforced
- [ ] Security headers configured
- [ ] CORS restricted to known origins

Secrets
- [ ] No secrets in source code or git history
- [ ] Environment variables / secrets manager used
- [ ] Secrets rotated regularly

Monitoring
- [ ] Failed auth attempts logged
- [ ] Error rate alerting configured
- [ ] Dependency vulnerabilities scanned in CI
```
