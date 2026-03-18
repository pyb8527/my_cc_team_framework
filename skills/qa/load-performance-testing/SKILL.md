---
name: load-performance-testing
description: Load and performance testing best practices using k6 and Locust. Covers test scenarios, ramp-up patterns, thresholds, Spring Boot performance tuning, and CI integration.
---

# Load & Performance Testing Best Practices

## k6 (JavaScript-based, recommended)

### Installation
```bash
# macOS
brew install k6

# Docker
docker run --rm -i grafana/k6 run - <script.js
```

### Basic Load Test
```javascript
// tests/load/api-load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time', true);

export const options = {
  stages: [
    { duration: '1m', target: 10 },   // Ramp up to 10 users
    { duration: '3m', target: 50 },   // Ramp up to 50 users
    { duration: '2m', target: 50 },   // Stay at 50 users
    { duration: '1m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],  // 95th < 500ms
    http_req_failed: ['rate<0.01'],                   // < 1% errors
    errors: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export function setup() {
  // Login once and return token for all VUs
  const res = http.post(`${BASE_URL}/api/v1/auth/login`, JSON.stringify({
    email: 'loadtest@example.com',
    password: 'testpassword',
  }), { headers: { 'Content-Type': 'application/json' } });

  return { token: res.json('data.accessToken') };
}

export default function (data) {
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${data.token}`,
  };

  // GET request
  const listRes = http.get(`${BASE_URL}/api/v1/meetups?page=1&size=20`, { headers });

  check(listRes, {
    'list status 200': (r) => r.status === 200,
    'list has data': (r) => r.json('data') !== null,
  });

  errorRate.add(listRes.status !== 200);
  responseTime.add(listRes.timings.duration);

  sleep(1);  // 1 second think time between requests
}

export function teardown(data) {
  // Cleanup if needed
}
```

### Spike Test
```javascript
export const options = {
  stages: [
    { duration: '10s', target: 5 },    // Normal load
    { duration: '1m', target: 5 },
    { duration: '10s', target: 200 },  // Spike!
    { duration: '1m', target: 200 },   // Stay at spike
    { duration: '10s', target: 5 },    // Back to normal
    { duration: '30s', target: 5 },
    { duration: '10s', target: 0 },
  ],
};
```

### Soak Test (endurance)
```javascript
export const options = {
  stages: [
    { duration: '5m', target: 20 },
    { duration: '4h', target: 20 },    // Sustained load — find memory leaks
    { duration: '5m', target: 0 },
  ],
};
```

## Locust (Python-based)

```python
# tests/load/locustfile.py
from locust import HttpUser, task, between
import json

class ApiUser(HttpUser):
    wait_time = between(1, 3)      # Think time between requests
    token = None

    def on_start(self):
        """Login before tests"""
        res = self.client.post('/api/v1/auth/login', json={
            'email': 'loadtest@example.com',
            'password': 'testpassword',
        })
        self.token = res.json()['data']['accessToken']
        self.client.headers.update({'Authorization': f'Bearer {self.token}'})

    @task(3)  # weight: called 3x more often than weight-1 tasks
    def list_meetups(self):
        with self.client.get('/api/v1/meetups', catch_response=True) as res:
            if res.status_code != 200:
                res.failure(f'Expected 200, got {res.status_code}')

    @task(1)
    def get_meetup_detail(self):
        self.client.get('/api/v1/meetups/1')

    @task(1)
    def create_meetup(self):
        self.client.post('/api/v1/meetups', json={
            'title': 'Load Test Meetup',
            'category': 'TECH',
            'maxMembers': 10,
        })
```

```bash
# Run headless
locust -f locustfile.py --headless -u 50 -r 5 \
  --host http://localhost:8080 \
  --run-time 5m \
  --csv results
```

## Spring Boot Performance Tuning

### JVM Options for Load Testing
```bash
java -Xms512m -Xmx1g \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -XX:+HeapDumpOnOutOfMemoryError \
  -jar app.jar
```

### Connection Pool (HikariCP)
```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20       # Tune based on load test results
      minimum-idle: 5
      connection-timeout: 30000   # 30s max wait for connection
      idle-timeout: 600000        # 10min idle before release
      max-lifetime: 1800000       # 30min max connection lifetime
```

### Async Endpoints
```java
// For long-running operations — non-blocking thread pool
@GetMapping("/reports")
public CompletableFuture<ApiResponse<ReportDto>> generateReport() {
    return CompletableFuture.supplyAsync(() -> {
        var report = reportService.generate();
        return ApiResponse.success(report);
    });
}
```

## Performance Baseline Targets

```
Endpoint type          P50     P95     P99    Error rate
────────────────────────────────────────────────────────
Simple GET (cached)    < 20ms  < 50ms  < 100ms   < 0.1%
Simple GET (DB)        < 50ms  < 200ms < 500ms   < 0.1%
Complex GET (joins)    < 100ms < 500ms < 1000ms  < 0.5%
POST / mutation        < 100ms < 500ms < 1000ms  < 0.5%
File upload            < 500ms < 2000ms < 5000ms < 1.0%
```

## CI Integration

```yaml
# .github/workflows/load-test.yml
- name: Run k6 load test
  uses: grafana/k6-action@v0.3.1
  with:
    filename: tests/load/api-load-test.js
    flags: --out json=results.json
  env:
    BASE_URL: ${{ secrets.STAGING_URL }}

- name: Check thresholds
  run: |
    p95=$(cat results.json | jq '[.metrics.http_req_duration.values[] | select(.key=="p(95)")] | .[0].value')
    if (( $(echo "$p95 > 500" | bc -l) )); then
      echo "P95 latency ${p95}ms exceeds 500ms threshold"
      exit 1
    fi
```

## Checklist

- [ ] Define performance SLAs before testing
- [ ] Test against staging with production-like data volume
- [ ] Warm up JVM before measuring (discard first 30s)
- [ ] Monitor DB connection pool utilization during test
- [ ] Check for memory growth over time (soak test)
- [ ] Profile with async-profiler on hot paths
- [ ] Test under degraded conditions (slow DB, high CPU)
