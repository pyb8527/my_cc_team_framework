---
name: api-documentation
description: OpenAPI 3.1 / Swagger API documentation best practices for Spring Boot (SpringDoc) and NestJS, including schema design, authentication docs, versioning, and generating client SDKs.
---

# API Documentation Best Practices (OpenAPI 3.1)

## Spring Boot — SpringDoc OpenAPI

### Dependency
```gradle
implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.6.0'
```

### Config
```java
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI openAPI() {
        return new OpenAPI()
            .info(new Info()
                .title("My API")
                .version("v1.0")
                .description("API 명세서")
                .contact(new Contact().name("Team").email("team@company.com")))
            .addSecurityItem(new SecurityRequirement().addList("bearerAuth"))
            .components(new Components()
                .addSecuritySchemes("bearerAuth", new SecurityScheme()
                    .type(SecurityScheme.Type.HTTP)
                    .scheme("bearer")
                    .bearerFormat("JWT")));
    }
}
```

### application.yml
```yaml
springdoc:
  swagger-ui:
    path: /swagger-ui.html
    tags-sorter: alpha
    operations-sorter: alpha
    display-request-duration: true
  api-docs:
    path: /v3/api-docs
  default-consumes-media-type: application/json
  default-produces-media-type: application/json
  show-actuator: false
```

### Controller Annotations
```java
@Tag(name = "Users", description = "사용자 관리 API")
@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    @Operation(
        summary = "사용자 조회",
        description = "ID로 사용자를 조회합니다.",
        security = @SecurityRequirement(name = "bearerAuth")
    )
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "조회 성공",
            content = @Content(schema = @Schema(implementation = UserResponse.class))),
        @ApiResponse(responseCode = "404", description = "사용자 없음",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
        @ApiResponse(responseCode = "401", description = "인증 필요")
    })
    @GetMapping("/{id}")
    public ApiResponse<UserResponse> getUser(@PathVariable Long id) { ... }
}
```

### DTO Schema Annotations
```java
@Schema(description = "사용자 생성 요청")
public record CreateUserRequest(
    @Schema(description = "이메일", example = "user@example.com", requiredMode = Schema.RequiredMode.REQUIRED)
    @Email @NotBlank String email,

    @Schema(description = "이름", example = "홍길동", minLength = 2, maxLength = 20)
    @NotBlank @Size(min = 2, max = 20) String name
) {}
```

## NestJS — @nestjs/swagger

### Setup
```typescript
const config = new DocumentBuilder()
  .setTitle('My API')
  .setVersion('1.0')
  .addBearerAuth(
    { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
    'access-token',
  )
  .build();

const document = SwaggerModule.createDocument(app, config);
SwaggerModule.setup('docs', app, document, {
  swaggerOptions: { persistAuthorization: true },
});
```

### DTO Annotations
```typescript
export class CreateUserDto {
  @ApiProperty({ description: '이메일', example: 'user@example.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ description: '이름', example: '홍길동', minLength: 2, maxLength: 20 })
  @IsString()
  @Length(2, 20)
  name: string;
}
```

### Controller Annotations
```typescript
@ApiTags('users')
@ApiBearerAuth('access-token')
@Controller({ path: 'users', version: '1' })
export class UserController {

  @ApiOperation({ summary: '사용자 조회' })
  @ApiOkResponse({ type: UserDto })
  @ApiNotFoundResponse({ description: '사용자 없음' })
  @Get(':id')
  getUser(@Param('id', ParseIntPipe) id: number): Promise<UserDto> { ... }
}
```

## OpenAPI Schema Best Practices

### Request/Response Design
```yaml
# Use $ref for reusable schemas
components:
  schemas:
    ApiError:
      type: object
      required: [code, message, timestamp]
      properties:
        code:
          type: string
          example: NOT_FOUND
        message:
          type: string
        errors:
          type: array
          items:
            $ref: '#/components/schemas/FieldError'
        timestamp:
          type: string
          format: date-time

    FieldError:
      type: object
      properties:
        field:
          type: string
        value:
          type: string
        reason:
          type: string
```

### Pagination Schema
```yaml
components:
  schemas:
    PageMeta:
      type: object
      properties:
        page: { type: integer, example: 1 }
        size: { type: integer, example: 20 }
        totalElements: { type: integer }
        totalPages: { type: integer }
        hasNext: { type: boolean }
```

## Versioning Strategy

```
# URI versioning (recommended)
/api/v1/users
/api/v2/users

# Header versioning
X-API-Version: 2

# Rules:
# - Never remove fields in a minor version
# - Deprecate with `deprecated: true` in OpenAPI + Sunset header
# - Maintain v(n-1) for at least 6 months after v(n) release
```

## Client SDK Generation

```bash
# Generate TypeScript client from OpenAPI spec
npx @openapitools/openapi-generator-cli generate \
  -i http://localhost:8080/v3/api-docs \
  -g typescript-axios \
  -o ./generated/api-client

# Generate Java client
openapi-generator generate \
  -i openapi.yaml \
  -g java \
  --library resttemplate \
  -o ./generated/java-client
```

## Checklist

- [ ] All endpoints have `@Operation` summary + description
- [ ] All responses documented (200, 400, 401, 403, 404, 500)
- [ ] Request/Response schemas have `example` values
- [ ] Authentication scheme configured globally
- [ ] Deprecated endpoints marked with `deprecated: true`
- [ ] Enum values documented with allowed values
- [ ] Pagination parameters consistent across endpoints
- [ ] Error response schema reused via `$ref`
