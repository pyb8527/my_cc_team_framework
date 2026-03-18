---
name: api-testing
description: REST API testing best practices using REST Assured (Java/Spring Boot), Supertest (Node.js), and Postman/Newman for collection-based testing, contract testing, and CI integration.
---

# REST API Testing Best Practices

## Spring Boot — REST Assured / MockMvc

### Integration Test with Real DB (Testcontainers)
```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class UserApiIntegrationTest {

    @Container
    static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0")
            .withDatabaseName("testdb")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", mysql::getJdbcUrl);
        registry.add("spring.datasource.username", mysql::getUsername);
        registry.add("spring.datasource.password", mysql::getPassword);
    }

    @LocalServerPort
    private int port;

    @Autowired
    private UserRepository userRepository;

    private RequestSpecification spec;

    @BeforeEach
    void setUp() {
        spec = new RequestSpecBuilder()
                .setBaseUri("http://localhost")
                .setPort(port)
                .setContentType(ContentType.JSON)
                .build();
        userRepository.deleteAll();
    }

    @Test
    void createUser_returnsCreatedUser() {
        var request = Map.of("email", "test@example.com", "name", "홍길동");

        given(spec)
            .body(request)
        .when()
            .post("/api/v1/users")
        .then()
            .statusCode(201)
            .body("success", equalTo(true))
            .body("data.email", equalTo("test@example.com"))
            .body("data.id", notNullValue());
    }

    @Test
    void getUser_notFound_returns404() {
        given(spec)
        .when()
            .get("/api/v1/users/999")
        .then()
            .statusCode(404)
            .body("code", equalTo("ENTITY_NOT_FOUND"));
    }
}
```

### MockMvc (No HTTP, Faster)
```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void getUser_success() throws Exception {
        var user = new UserResponse(1L, "test@example.com", "홍길동");
        when(userService.findById(1L)).thenReturn(user);

        mockMvc.perform(get("/api/v1/users/1")
                .header("Authorization", "Bearer " + getTestToken()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.success").value(true))
            .andExpect(jsonPath("$.data.email").value("test@example.com"))
            .andDo(print());
    }

    @Test
    void createUser_invalidEmail_returns400() throws Exception {
        var request = Map.of("email", "not-valid", "name", "홍길동");

        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.code").value("INVALID_INPUT"))
            .andExpect(jsonPath("$.errors[0].field").value("email"));
    }
}
```

## Node.js — Supertest

```typescript
// tests/api/users.test.ts
import request from 'supertest';
import { app } from '../../src/app';
import { db } from '../../src/db';

describe('Users API', () => {
  beforeAll(async () => db.migrate.latest());
  afterAll(async () => db.destroy());
  beforeEach(async () => db.seed.run());

  it('POST /api/v1/users — creates user', async () => {
    const res = await request(app)
      .post('/api/v1/users')
      .send({ email: 'test@example.com', name: '홍길동' })
      .expect(201);

    expect(res.body.success).toBe(true);
    expect(res.body.data.email).toBe('test@example.com');
    expect(res.body.data.id).toBeDefined();
  });

  it('GET /api/v1/users/:id — 404 for missing user', async () => {
    const res = await request(app)
      .get('/api/v1/users/99999')
      .set('Authorization', `Bearer ${testToken}`)
      .expect(404);

    expect(res.body.code).toBe('NOT_FOUND');
  });

  it('GET /api/v1/users/me — returns current user', async () => {
    const token = generateTestToken({ userId: 1, role: 'USER' });

    const res = await request(app)
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(res.body.data.id).toBe(1);
  });
});
```

## Postman / Newman (Collection-Based)

```json
// Sample Postman collection structure (postman_collection.json)
{
  "info": { "name": "MyApp API Tests" },
  "item": [
    {
      "name": "Auth",
      "item": [
        {
          "name": "Login",
          "event": [{
            "listen": "test",
            "script": {
              "exec": [
                "pm.test('Status 200', () => pm.response.to.have.status(200));",
                "pm.test('Has token', () => {",
                "  const body = pm.response.json();",
                "  pm.expect(body.data.accessToken).to.be.a('string');",
                "  pm.collectionVariables.set('token', body.data.accessToken);",
                "});"
              ]
            }
          }],
          "request": {
            "method": "POST",
            "url": "{{baseUrl}}/api/v1/auth/login",
            "body": {
              "mode": "raw",
              "raw": "{\"email\": \"{{testEmail}}\", \"password\": \"{{testPassword}}\"}"
            }
          }
        }
      ]
    }
  ]
}
```

```bash
# Run in CI
newman run postman_collection.json \
  --environment postman_env.json \
  --reporters cli,junit \
  --reporter-junit-export results.xml \
  --bail  # Stop on first failure
```

## API Testing Checklist

### For Each Endpoint
- [ ] Happy path (valid input → expected response)
- [ ] Invalid input (missing required fields, wrong types)
- [ ] Boundary values (empty string, max length, 0, negative numbers)
- [ ] Authentication (missing token → 401, wrong token → 401)
- [ ] Authorization (valid token but wrong role → 403)
- [ ] Not found (non-existent resource → 404)
- [ ] Duplicate (conflict on unique constraint → 409)

### Response Validation
- [ ] Status code correct
- [ ] Response body schema matches spec
- [ ] Error response has `code` + `message` fields
- [ ] Timestamps in ISO 8601 format
- [ ] Pagination metadata present on list endpoints

### Performance
- [ ] P99 < 200ms for read endpoints
- [ ] P99 < 500ms for write endpoints
- [ ] Response time logged and monitored
