---
name: fastapi-python
description: FastAPI best practices for building high-performance Python REST APIs with async support, dependency injection, Pydantic validation, SQLAlchemy ORM, and production-ready structure.
---

# FastAPI Python Best Practices

## Project Structure

```
project/
├── app/
│   ├── main.py                    # FastAPI app factory
│   ├── core/
│   │   ├── config.py              # Settings (pydantic-settings)
│   │   ├── security.py            # JWT / password hashing
│   │   └── dependencies.py        # Common DI (get_db, get_current_user)
│   ├── api/
│   │   └── v1/
│   │       ├── router.py          # APIRouter aggregation
│   │       └── endpoints/         # Route handlers per domain
│   ├── domain/
│   │   └── {domain}/
│   │       ├── models.py          # SQLAlchemy ORM models
│   │       ├── schemas.py         # Pydantic request/response schemas
│   │       ├── service.py         # Business logic
│   │       └── repository.py      # DB queries
│   └── db/
│       ├── session.py             # SQLAlchemy engine + session
│       └── base.py                # Base model with timestamps
├── alembic/                       # DB migrations
├── tests/
├── pyproject.toml
└── .env
```

## Core Dependencies (pyproject.toml)

```toml
[project]
dependencies = [
    "fastapi>=0.115.0",
    "uvicorn[standard]>=0.32.0",
    "pydantic-settings>=2.6.0",
    "sqlalchemy>=2.0.0",
    "alembic>=1.14.0",
    "asyncpg>=0.30.0",          # PostgreSQL async driver
    "python-jose[cryptography]>=3.3.0",  # JWT
    "passlib[bcrypt]>=1.7.4",
    "python-multipart>=0.0.12",  # Form / file upload
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0.0",
    "pytest-asyncio>=0.24.0",
    "httpx>=0.27.0",             # TestClient
    "pytest-cov>=5.0.0",
]
```

## App Factory (main.py)

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.core.config import settings
from app.api.v1.router import api_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    # startup
    yield
    # shutdown


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.APP_NAME,
        version="1.0.0",
        lifespan=lifespan,
        docs_url="/docs" if settings.DEBUG else None,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(api_router, prefix="/api/v1")
    return app


app = create_app()
```

## Settings (core/config.py)

```python
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import list


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    APP_NAME: str = "MyApp"
    DEBUG: bool = False

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://user:pass@localhost/db"

    # JWT
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # CORS
    CORS_ORIGINS: list[str] = ["http://localhost:3000"]


settings = Settings()
```

## Base Model with Timestamps (db/base.py)

```python
from sqlalchemy import DateTime, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from datetime import datetime


class Base(DeclarativeBase):
    pass


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
        onupdate=func.now(), nullable=False
    )
```

## Async Session (db/session.py)

```python
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.core.config import settings

engine = create_async_engine(settings.DATABASE_URL, echo=settings.DEBUG)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
```

## Standard Response Schema

```python
from pydantic import BaseModel
from typing import Generic, TypeVar

T = TypeVar("T")


class ApiResponse(BaseModel, Generic[T]):
    success: bool = True
    data: T | None = None
    message: str | None = None

    @classmethod
    def ok(cls, data: T) -> "ApiResponse[T]":
        return cls(success=True, data=data)

    @classmethod
    def error(cls, message: str) -> "ApiResponse[None]":
        return cls(success=False, message=message)
```

## Exception Handling

```python
from fastapi import Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError


class BusinessException(Exception):
    def __init__(self, status_code: int, code: str, message: str):
        self.status_code = status_code
        self.code = code
        self.message = message


async def business_exception_handler(request: Request, exc: BusinessException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"code": exc.code, "message": exc.message, "errors": []},
    )


async def validation_exception_handler(request: Request, exc: RequestValidationError):
    errors = [
        {"field": e["loc"][-1], "reason": e["msg"]}
        for e in exc.errors()
    ]
    return JSONResponse(
        status_code=422,
        content={"code": "VALIDATION_ERROR", "message": "입력값이 유효하지 않습니다.", "errors": errors},
    )
```

## Security (core/security.py)

```python
from datetime import datetime, timedelta, timezone
from jose import jwt, JWTError
from passlib.context import CryptContext
from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def create_access_token(subject: str | int) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode(
        {"sub": str(subject), "exp": expire, "type": "access"},
        settings.SECRET_KEY, algorithm=settings.ALGORITHM,
    )


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except JWTError:
        raise BusinessException(401, "UNAUTHORIZED", "유효하지 않은 토큰입니다.")
```

## Dependency Injection (core/dependencies.py)

```python
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db
from app.core.security import decode_token

bearer = HTTPBearer()


async def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
) -> int:
    payload = decode_token(credentials.credentials)
    return int(payload["sub"])
```

## Repository Pattern

```python
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.domain.user.models import User


class UserRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def find_by_id(self, user_id: int) -> User | None:
        result = await self.db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

    async def save(self, user: User) -> User:
        self.db.add(user)
        await self.db.flush()
        await self.db.refresh(user)
        return user
```

## Best Practices

### Performance
- Use `async def` for all route handlers and DB calls
- Use `select()` with explicit columns to avoid SELECT *
- Use `joinedload()` / `selectinload()` to prevent N+1
- Set `expire_on_commit=False` in session maker

### Validation
- Use Pydantic v2 `model_validator` for cross-field validation
- Use `Annotated` types for reusable field constraints
- Use `response_model_exclude_none=True` on routes

### Security
- Never log passwords or tokens
- Use `HTTPBearer` (not OAuth2PasswordBearer) for JWT
- Validate token `type` claim to prevent access/refresh confusion
- Rate limit with `slowapi`

### Testing
```python
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app


@pytest.fixture
async def client():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c


@pytest.mark.asyncio
async def test_health(client):
    response = await client.get("/api/v1/health")
    assert response.status_code == 200
```
