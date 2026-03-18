---
name: mongodb-best-practices
description: MongoDB schema design, indexing strategy, aggregation pipelines, and best practices for Node.js (Mongoose) and Spring Boot (Spring Data MongoDB).
---

# MongoDB Best Practices

## Schema Design Principles

### Embed vs Reference
```
Embed when:
  - Data is always accessed together (1:1, 1:few)
  - Child data doesn't exceed 16MB document limit
  - Child data rarely changes independently

Reference when:
  - 1:many (hundreds+)
  - Data is accessed independently
  - Many-to-many relationships
```

### Document Structure
```javascript
// Good: embed frequently co-read data
{
  _id: ObjectId("..."),
  title: "Post Title",
  author: {           // embedded (small, rarely changes)
    id: ObjectId("..."),
    name: "홍길동",
    avatarUrl: "..."
  },
  tags: ["nodejs", "mongodb"],   // embed small arrays
  commentCount: 42,              // denormalized counter
  createdAt: ISODate("..."),
  updatedAt: ISODate("...")
}

// Reference for large/independent collections
{
  _id: ObjectId("..."),
  postId: ObjectId("..."),  // reference
  userId: ObjectId("..."),  // reference
  content: "...",
  createdAt: ISODate("...")
}
```

## Indexing Strategy

```javascript
// Single field
db.users.createIndex({ email: 1 }, { unique: true })

// Compound (order matters — ESR rule: Equality, Sort, Range)
db.orders.createIndex({ userId: 1, status: 1, createdAt: -1 })

// Text search
db.posts.createIndex({ title: "text", content: "text" })

// Sparse (only index documents that have the field)
db.users.createIndex({ deletedAt: 1 }, { sparse: true })

// TTL (auto-expire documents)
db.sessions.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 })

// Covered query (all fields in index — no document fetch)
db.orders.createIndex({ userId: 1, status: 1, total: 1 })
db.orders.find({ userId: id, status: "PAID" }, { _id: 0, status: 1, total: 1 })
```

## Aggregation Pipeline

```javascript
// Efficient aggregation order: $match → $sort → $limit → $lookup → $project
db.orders.aggregate([
  // 1. Filter first (uses indexes)
  { $match: { userId: ObjectId("..."), status: "PAID" } },

  // 2. Sort before limit
  { $sort: { createdAt: -1 } },

  // 3. Limit before lookup (reduce docs to join)
  { $limit: 20 },

  // 4. Lookup (JOIN equivalent)
  { $lookup: {
    from: "products",
    localField: "productId",
    foreignField: "_id",
    as: "product",
    pipeline: [{ $project: { name: 1, price: 1 } }]  // project in lookup
  }},
  { $unwind: "$product" },

  // 5. Project last
  { $project: {
    orderId: "$_id",
    productName: "$product.name",
    total: 1,
    createdAt: 1
  }}
])
```

## Mongoose (Node.js)

```typescript
// Schema definition
import { Schema, model, Document } from 'mongoose';

interface IUser extends Document {
  email: string;
  name: string;
  role: 'USER' | 'ADMIN';
  createdAt: Date;
  updatedAt: Date;
}

const userSchema = new Schema<IUser>(
  {
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    name: { type: String, required: true, trim: true, maxlength: 50 },
    role: { type: String, enum: ['USER', 'ADMIN'], default: 'USER' },
  },
  {
    timestamps: true,           // auto createdAt, updatedAt
    versionKey: false,          // disable __v
    toJSON: {
      transform: (_, ret) => {
        ret.id = ret._id;
        delete ret._id;
        return ret;
      }
    }
  }
);

// Instance methods
userSchema.methods.isAdmin = function(): boolean {
  return this.role === 'ADMIN';
};

export const User = model<IUser>('User', userSchema);
```

```typescript
// Repository pattern with Mongoose
export class UserRepository {
  async findByEmail(email: string): Promise<IUser | null> {
    return User.findOne({ email }).lean();  // .lean() returns plain JS object (faster)
  }

  async findActiveUsers(page: number, size: number) {
    const [data, total] = await Promise.all([
      User.find({ deletedAt: null })
        .sort({ createdAt: -1 })
        .skip((page - 1) * size)
        .limit(size)
        .lean(),
      User.countDocuments({ deletedAt: null }),
    ]);
    return { data, total, page, size };
  }

  async updateById(id: string, update: Partial<IUser>): Promise<IUser | null> {
    return User.findByIdAndUpdate(
      id,
      { $set: update },
      { new: true, runValidators: true }  // return updated doc + run schema validators
    ).lean();
  }
}
```

## Spring Boot — Spring Data MongoDB

```java
// build.gradle
implementation 'org.springframework.boot:spring-boot-starter-data-mongodb'

// application.yml
spring:
  data:
    mongodb:
      uri: ${MONGODB_URI:mongodb://localhost:27017/mydb}

// Document class
@Document(collection = "users")
@Data
@NoArgsConstructor
public class UserDocument {
    @Id
    private String id;

    @Indexed(unique = true)
    private String email;

    private String name;

    @CreatedDate
    private LocalDateTime createdAt;

    @LastModifiedDate
    private LocalDateTime updatedAt;
}

// Repository
public interface UserRepository extends MongoRepository<UserDocument, String> {
    Optional<UserDocument> findByEmail(String email);
    Page<UserDocument> findByRole(String role, Pageable pageable);
}

// Custom aggregation
@Repository
@RequiredArgsConstructor
public class UserAggregationRepository {
    private final MongoTemplate mongoTemplate;

    public List<UserStats> getUserStats() {
        Aggregation agg = Aggregation.newAggregation(
            Aggregation.match(Criteria.where("deletedAt").isNull()),
            Aggregation.group("role").count().as("count"),
            Aggregation.project("count").and("_id").as("role")
        );
        return mongoTemplate.aggregate(agg, "users", UserStats.class).getMappedResults();
    }
}
```

## Best Practices

### Performance
- Use `.lean()` in Mongoose for read-only queries (3-5x faster)
- Use projection to fetch only needed fields
- Avoid `$where` and JavaScript execution in queries
- Use `bulkWrite()` for batch inserts/updates
- Set `maxTimeMS` on slow queries to prevent runaway queries

### Data Integrity
- Use transactions for multi-document writes (MongoDB 4.0+)
- Validate at application layer (Mongoose validators / Bean Validation)
- Use atomic operators: `$inc`, `$push`, `$pull`, `$addToSet`

### Security
- Never expose `_id` ObjectId directly — map to string `id`
- Sanitize query inputs to prevent NoSQL injection (`$where`, `$regex`)
- Use field-level encryption for PII data
- Enable MongoDB authentication — never run without auth in production

### Operations
- Monitor slow queries with `db.setProfilingLevel(1, { slowms: 100 })`
- Use replica sets (minimum 3 nodes) for HA
- Enable WiredTiger compression for storage efficiency
- Regular index audits: `db.collection.getIndexes()`
