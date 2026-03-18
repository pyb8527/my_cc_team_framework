---
name: unit-testing-jest-vitest
description: Unit testing best practices for JavaScript/TypeScript using Jest and Vitest. Covers test structure, mocking, async tests, React component testing with Testing Library, and coverage configuration.
---

# Unit Testing with Jest & Vitest

## Setup

### Vitest (Recommended for Vite/Next.js projects)
```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/tests/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      exclude: ['node_modules/', '**/*.d.ts', '**/*.config.*'],
      thresholds: { lines: 80, functions: 80, branches: 70 },
    },
  },
});
```

### Jest (Node.js / non-Vite projects)
```json
// package.json
{
  "jest": {
    "preset": "ts-jest",
    "testEnvironment": "node",
    "setupFilesAfterFramework": ["<rootDir>/src/tests/setup.ts"],
    "collectCoverageFrom": ["src/**/*.ts", "!src/**/*.d.ts"],
    "coverageThreshold": {
      "global": { "lines": 80, "functions": 80 }
    }
  }
}
```

## Test Structure (AAA Pattern)

```typescript
describe('UserService', () => {
  // Group related tests
  describe('findById', () => {
    it('returns user when found', async () => {
      // Arrange
      const mockUser = { id: 1, email: 'test@example.com', name: '홍길동' };
      mockUserRepository.findById.mockResolvedValue(mockUser);

      // Act
      const result = await userService.findById(1);

      // Assert
      expect(result).toEqual(mockUser);
      expect(mockUserRepository.findById).toHaveBeenCalledWith(1);
      expect(mockUserRepository.findById).toHaveBeenCalledTimes(1);
    });

    it('throws NotFoundException when user not found', async () => {
      mockUserRepository.findById.mockResolvedValue(null);

      await expect(userService.findById(999)).rejects.toThrow(NotFoundException);
    });
  });
});
```

## Mocking Patterns

```typescript
// Module mock
vi.mock('@/lib/email', () => ({
  sendEmail: vi.fn().mockResolvedValue({ messageId: 'test-123' }),
}));

// Partial mock — keep real implementation, override specific methods
vi.mock('@/repositories/userRepository', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@/repositories/userRepository')>();
  return {
    ...actual,
    findByEmail: vi.fn(),
  };
});

// Spy on existing method
const sendEmailSpy = vi.spyOn(emailService, 'send').mockResolvedValue(undefined);

// Type-safe mock factory
function createMockUserRepository(): jest.Mocked<UserRepository> {
  return {
    findById: jest.fn(),
    findByEmail: jest.fn(),
    save: jest.fn(),
    delete: jest.fn(),
  };
}

// Date mocking
beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2024-01-15T10:00:00Z'));
});
afterEach(() => vi.useRealTimers());
```

## Async Tests

```typescript
// Promise rejection
it('rejects with error on network failure', async () => {
  mockFetch.mockRejectedValue(new NetworkError('Connection refused'));
  await expect(apiClient.getUser(1)).rejects.toThrow('Connection refused');
});

// Multiple async assertions
it('sends notification after user creation', async () => {
  await userService.create({ email: 'test@example.com', name: 'Test' });

  // Assert side effects
  expect(notificationService.send).toHaveBeenCalledWith(
    expect.objectContaining({ type: 'WELCOME', email: 'test@example.com' })
  );
});
```

## React Component Testing (Testing Library)

```typescript
// setup.ts
import '@testing-library/jest-dom';

// Component test
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { LoginForm } from './LoginForm';

describe('LoginForm', () => {
  const onSubmit = vi.fn();

  beforeEach(() => onSubmit.mockClear());

  it('renders email and password fields', () => {
    render(<LoginForm onSubmit={onSubmit} />);
    expect(screen.getByLabelText(/이메일/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/비밀번호/i)).toBeInTheDocument();
  });

  it('submits form with entered values', async () => {
    const user = userEvent.setup();
    render(<LoginForm onSubmit={onSubmit} />);

    await user.type(screen.getByLabelText(/이메일/i), 'test@example.com');
    await user.type(screen.getByLabelText(/비밀번호/i), 'password123');
    await user.click(screen.getByRole('button', { name: /로그인/i }));

    expect(onSubmit).toHaveBeenCalledWith({
      email: 'test@example.com',
      password: 'password123',
    });
  });

  it('shows validation error for invalid email', async () => {
    const user = userEvent.setup();
    render(<LoginForm onSubmit={onSubmit} />);

    await user.type(screen.getByLabelText(/이메일/i), 'not-valid');
    await user.click(screen.getByRole('button', { name: /로그인/i }));

    expect(await screen.findByRole('alert')).toHaveTextContent(/유효한 이메일/i);
    expect(onSubmit).not.toHaveBeenCalled();
  });
});
```

## Custom Matchers & Utilities

```typescript
// Test data builders (avoid magic literals)
function buildUser(overrides?: Partial<User>): User {
  return {
    id: 1,
    email: 'default@example.com',
    name: '기본 사용자',
    role: 'USER',
    createdAt: new Date('2024-01-01'),
    ...overrides,
  };
}

// Usage
const adminUser = buildUser({ role: 'ADMIN' });
const newUser = buildUser({ id: 2, email: 'new@example.com' });
```

## What to Test

```
✅ Test:
  - Business logic (calculations, transformations, validations)
  - Error paths and edge cases
  - Component behavior from user perspective
  - Side effects (emails sent, events emitted, DB writes)

❌ Don't test:
  - Implementation details (internal state, private methods)
  - Third-party library internals
  - Type correctness (TypeScript handles this)
  - Simple getters/setters with no logic
```

## Coverage Guide

```
Target coverage by layer:
  Domain / Business logic  → 90%+
  Service layer            → 80%+
  Controllers              → 70%+ (or use integration tests)
  Utilities / helpers      → 90%+
  UI components            → 60-70% (supplement with E2E)

Coverage metrics:
  Lines      → are all lines executed?
  Branches   → are all if/else paths covered?
  Functions  → are all functions called?
```
