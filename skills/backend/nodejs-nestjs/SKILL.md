---
name: nodejs-nestjs
description: NestJS best practices for building scalable Node.js REST APIs with TypeScript, dependency injection, Guards, Interceptors, Pipes, TypeORM, and modular architecture.
---

# NestJS Best Practices

## Project Structure

```
src/
├── main.ts                        # Bootstrap & global setup
├── app.module.ts                  # Root module
├── common/
│   ├── decorators/                # @CurrentUser, @Roles, etc.
│   ├── filters/                   # GlobalExceptionFilter
│   ├── guards/                    # JwtAuthGuard, RolesGuard
│   ├── interceptors/              # ResponseTransformInterceptor, LoggingInterceptor
│   ├── pipes/                     # ValidationPipe config
│   └── dto/                       # ApiResponse, PageDto
├── config/                        # ConfigModule + validation schemas
└── modules/
    └── {domain}/
        ├── {domain}.module.ts
        ├── {domain}.controller.ts
        ├── {domain}.service.ts
        ├── {domain}.repository.ts
        ├── entities/
        ├── dto/
        └── exceptions/
```

## Bootstrap (main.ts)

```typescript
import { NestFactory } from '@nestjs/core';
import { ValidationPipe, VersioningType } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Global validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,           // Strip unknown properties
      forbidNonWhitelisted: true,
      transform: true,           // Auto-transform types
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  // URI versioning: /v1/users
  app.enableVersioning({ type: VersioningType.URI });

  // CORS
  app.enableCors({
    origin: process.env.CORS_ORIGINS?.split(',') ?? ['http://localhost:3000'],
    credentials: true,
  });

  // Swagger
  if (process.env.NODE_ENV !== 'production') {
    const config = new DocumentBuilder()
      .setTitle('API Docs')
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, config));
  }

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
```

## Standard Response Format

```typescript
// common/dto/api-response.dto.ts
export class ApiResponse<T> {
  success: boolean;
  data?: T;
  message?: string;

  static ok<T>(data: T): ApiResponse<T> {
    return { success: true, data };
  }

  static error(message: string): ApiResponse<null> {
    return { success: false, message };
  }
}
```

## Global Exception Filter

```typescript
// common/filters/http-exception.filter.ts
import { ExceptionFilter, Catch, ArgumentsHost, HttpException, HttpStatus, Logger } from '@nestjs/common';
import { Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const exceptionResponse = exception.getResponse();
      response.status(status).json(
        typeof exceptionResponse === 'object'
          ? exceptionResponse
          : { code: 'ERROR', message: exceptionResponse },
      );
    } else {
      this.logger.error('Unexpected error', exception instanceof Error ? exception.stack : exception);
      response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
        code: 'INTERNAL_ERROR',
        message: '서버 내부 오류가 발생했습니다.',
      });
    }
  }
}
```

## JWT Auth Guard

```typescript
// common/guards/jwt-auth.guard.ts
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  handleRequest(err: any, user: any) {
    if (err || !user) throw new UnauthorizedException('인증이 필요합니다.');
    return user;
  }
}
```

## Current User Decorator

```typescript
// common/decorators/current-user.decorator.ts
import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const CurrentUser = createParamDecorator(
  (data: keyof JwtPayload | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const user = request.user as JwtPayload;
    return data ? user?.[data] : user;
  },
);
```

## Base Entity with Timestamps

```typescript
// common/entities/base.entity.ts
import { CreateDateColumn, UpdateDateColumn, PrimaryGeneratedColumn } from 'typeorm';

export abstract class BaseEntity {
  @PrimaryGeneratedColumn('increment')
  id: number;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
```

## Module Example

```typescript
// modules/user/user.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserController } from './user.controller';
import { UserService } from './user.service';
import { UserEntity } from './entities/user.entity';

@Module({
  imports: [TypeOrmModule.forFeature([UserEntity])],
  controllers: [UserController],
  providers: [UserService],
  exports: [UserService],
})
export class UserModule {}
```

## Controller Pattern

```typescript
@Controller({ path: 'users', version: '1' })
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
@ApiTags('users')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Get('me')
  async getMe(@CurrentUser('userId') userId: number): Promise<ApiResponse<UserDto>> {
    const user = await this.userService.findById(userId);
    return ApiResponse.ok(user);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(@Body() dto: CreateUserDto): Promise<ApiResponse<UserDto>> {
    const user = await this.userService.create(dto);
    return ApiResponse.ok(user);
  }
}
```

## Config Module (Validated)

```typescript
// config/app.config.ts
import { registerAs } from '@nestjs/config';
import * as Joi from 'joi';

export const appConfig = registerAs('app', () => ({
  port: parseInt(process.env.PORT ?? '3000'),
  jwtSecret: process.env.JWT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '1h',
}));

export const validationSchema = Joi.object({
  PORT: Joi.number().default(3000),
  JWT_SECRET: Joi.string().required(),
  DATABASE_URL: Joi.string().required(),
});
```

## Best Practices

- **Never** use `@Injectable()` on entities
- **Always** whitelist DTOs with `class-validator` decorators
- Use `@ApiProperty()` on all DTO fields for Swagger
- Use `ConfigService` — never `process.env` directly in services
- Use `forwardRef()` sparingly to avoid circular dependencies
- Use `onModuleInit()` for startup side-effects, not constructors
- Set `synchronize: false` in production TypeORM config
- Use transactions with `DataSource.transaction()` for multi-step writes
