---
name: graphql-patterns
description: GraphQL API design patterns with schema-first and code-first approaches, resolvers, DataLoader for N+1 prevention, subscriptions, and best practices for Spring Boot and Node.js.
---

# GraphQL API Design Patterns

## Schema-First Design Principles

```graphql
# Always define scalars explicitly
scalar DateTime
scalar Upload

# Use interfaces for polymorphism
interface Node {
  id: ID!
}

# Prefer connections for paginated lists
type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type UserEdge {
  node: User!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}

# Mutations: input types + payload types
input CreateUserInput {
  email: String!
  name: String!
}

type CreateUserPayload {
  user: User
  errors: [UserError!]!
}

type UserError {
  field: String
  message: String!
  code: String!
}
```

## NestJS Code-First (GraphQL Module)

```typescript
// app.module.ts
GraphQLModule.forRoot<ApolloDriverConfig>({
  driver: ApolloDriver,
  autoSchemaFile: join(process.cwd(), 'src/schema.gql'),
  sortSchema: true,
  context: ({ req }) => ({ req }),
  formatError: (error) => ({
    message: error.message,
    code: error.extensions?.code ?? 'INTERNAL_ERROR',
    path: error.path,
  }),
}),
```

## Resolver Pattern (NestJS)

```typescript
@Resolver(() => User)
export class UserResolver {
  constructor(
    private userService: UserService,
    @InjectDataLoader(PostsByUserLoader)
    private postsByUserLoader: DataLoader<number, Post[]>,
  ) {}

  @Query(() => UserConnection)
  async users(@Args() args: PaginationArgs): Promise<UserConnection> {
    return this.userService.findAll(args);
  }

  @Query(() => User, { nullable: true })
  async user(@Args('id', { type: () => Int }) id: number): Promise<User | null> {
    return this.userService.findById(id);
  }

  @Mutation(() => CreateUserPayload)
  async createUser(@Args('input') input: CreateUserInput): Promise<CreateUserPayload> {
    try {
      const user = await this.userService.create(input);
      return { user, errors: [] };
    } catch (err) {
      return { user: null, errors: [{ message: err.message, code: 'CREATE_FAILED' }] };
    }
  }

  // Field resolver — use DataLoader to batch N+1
  @ResolveField(() => [Post])
  async posts(@Parent() user: User): Promise<Post[]> {
    return this.postsByUserLoader.load(user.id);
  }
}
```

## DataLoader (N+1 Prevention)

```typescript
// posts-by-user.loader.ts
@Injectable()
export class PostsByUserLoader implements NestDataLoader<number, Post[]> {
  constructor(private postService: PostService) {}

  generateDataLoader(): DataLoader<number, Post[]> {
    return new DataLoader(async (userIds: readonly number[]) => {
      const posts = await this.postService.findByUserIds([...userIds]);
      const grouped = new Map<number, Post[]>();
      userIds.forEach((id) => grouped.set(id, []));
      posts.forEach((p) => grouped.get(p.userId)?.push(p));
      return userIds.map((id) => grouped.get(id) ?? []);
    });
  }
}
```

## Spring Boot (graphql-java / Spring for GraphQL)

```java
// build.gradle
implementation 'org.springframework.boot:spring-boot-starter-graphql'

// src/main/resources/graphql/schema.graphqls — schema file

@Controller
public class UserController {

    private final UserService userService;

    @QueryMapping
    public List<User> users() {
        return userService.findAll();
    }

    @QueryMapping
    public User userById(@Argument Long id) {
        return userService.findById(id);
    }

    @MutationMapping
    public User createUser(@Argument CreateUserInput input) {
        return userService.create(input);
    }

    @SchemaMapping(typeName = "User", field = "posts")
    public List<Post> posts(User user, @BatchLoader PostBatchLoader loader) {
        return loader.load(user.getId());
    }
}
```

## Authentication in GraphQL

```typescript
// Use HTTP context — never pass tokens as arguments
@Query(() => User)
@UseGuards(GqlJwtAuthGuard)
async me(@CurrentUser() user: JwtPayload): Promise<User> {
  return this.userService.findById(user.userId);
}

// GqlJwtAuthGuard bridges HTTP → GraphQL context
@Injectable()
export class GqlJwtAuthGuard extends AuthGuard('jwt') {
  getRequest(context: ExecutionContext) {
    const ctx = GqlExecutionContext.create(context);
    return ctx.getContext().req;
  }
}
```

## Error Handling

```typescript
// Use union types for expected errors (NOT exceptions)
type CreateUserResult = User | ValidationError | DuplicateEmailError

// Use exceptions only for unexpected errors (auth, network, etc.)
// GraphQL error codes follow:
// UNAUTHENTICATED, FORBIDDEN, NOT_FOUND, BAD_USER_INPUT, INTERNAL_SERVER_ERROR
```

## Best Practices

- **Schema Design**
  - Use `!` (non-null) aggressively — only nullable when truly optional
  - Avoid returning raw IDs in favor of typed objects
  - Use Relay-style Connections for all lists that may paginate
  - Prefix mutations with verb: `createUser`, `updateUser`, `deleteUser`

- **Performance**
  - Always use DataLoader for 1:N and N:N field resolvers
  - Use `@Complexity()` decorator to limit query depth/cost
  - Enable persisted queries in production
  - Disable introspection in production

- **Security**
  - Validate and sanitize all input arguments
  - Use field-level authorization (`@UseGuards` on resolvers)
  - Rate limit by query complexity, not just request count
  - Never expose internal error details in `extensions.exception`
