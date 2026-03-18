---
name: database-migration
description: Database migration best practices using Flyway and Liquibase for Spring Boot, including versioning strategy, rollback patterns, team workflow, and CI/CD integration.
---

# Database Migration Best Practices

## Flyway (Spring Boot)

### Dependency
```gradle
implementation 'org.flywaydb:flyway-core'
implementation 'org.flywaydb:flyway-mysql'  // for MySQL
```

### Configuration
```yaml
spring:
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true     # for existing DBs
    out-of-order: false           # enforce strict ordering
    validate-on-migrate: true     # fail if checksums mismatch
    table: flyway_schema_history
```

### File Naming Convention
```
src/main/resources/db/migration/
├── V1__create_users_table.sql
├── V2__add_email_index.sql
├── V3__create_posts_table.sql
├── V3.1__add_post_category.sql   # sub-version for hotfixes
└── R__create_views.sql           # Repeatable: runs when content changes
```

**Rules:**
- `V{version}__{description}.sql` — versioned (runs once)
- `R__{description}.sql` — repeatable (runs when checksum changes)
- `U{version}__{description}.sql` — undo (Flyway Pro)
- Version: integers or dots (`1`, `1.1`, `20240318`)
- Description: underscores as spaces

### SQL Migration Examples

```sql
-- V1__create_users_table.sql
CREATE TABLE users (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    email      VARCHAR(255) NOT NULL,
    name       VARCHAR(100) NOT NULL,
    role       VARCHAR(20)  NOT NULL DEFAULT 'USER',
    created_at DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- V2__add_users_deleted_at.sql
-- Always use nullable + soft delete pattern
ALTER TABLE users
    ADD COLUMN deleted_at DATETIME(6) NULL AFTER updated_at;

CREATE INDEX idx_users_deleted_at ON users (deleted_at);

-- V3__create_posts_table.sql
CREATE TABLE posts (
    id         BIGINT        NOT NULL AUTO_INCREMENT,
    user_id    BIGINT        NOT NULL,
    title      VARCHAR(255)  NOT NULL,
    content    TEXT          NOT NULL,
    status     VARCHAR(20)   NOT NULL DEFAULT 'DRAFT',
    created_at DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    INDEX idx_posts_user_id (user_id),
    CONSTRAINT fk_posts_user_id FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### Java-based Migration (complex data transforms)
```java
// V4__migrate_user_roles.java
public class V4__migrate_user_roles extends BaseJavaMigration {
    @Override
    public void migrate(Context context) throws Exception {
        try (var statement = context.getConnection().createStatement()) {
            statement.execute("UPDATE users SET role = 'MEMBER' WHERE role = 'USER'");
        }
    }
}
```

## Liquibase (Alternative)

### Dependency
```gradle
implementation 'org.liquibase:liquibase-core'
```

### Master Changelog (YAML)
```yaml
# src/main/resources/db/changelog/db.changelog-master.yaml
databaseChangeLog:
  - include:
      file: db/changelog/changes/001-create-users.yaml
  - include:
      file: db/changelog/changes/002-create-posts.yaml
```

### Changeset
```yaml
# db/changelog/changes/001-create-users.yaml
databaseChangeLog:
  - changeSet:
      id: 001-create-users
      author: dev-team
      changes:
        - createTable:
            tableName: users
            columns:
              - column:
                  name: id
                  type: BIGINT
                  autoIncrement: true
                  constraints:
                    primaryKey: true
              - column:
                  name: email
                  type: VARCHAR(255)
                  constraints:
                    nullable: false
                    unique: true
              - column:
                  name: created_at
                  type: DATETIME
                  defaultValueComputed: CURRENT_TIMESTAMP
      rollback:
        - dropTable:
            tableName: users
```

## Team Workflow

### Branching Strategy
```
main branch  →  V1, V2, V3 (released)
feature/A    →  V4__feature_a.sql
feature/B    →  V4__feature_b.sql  ← CONFLICT!

Resolution:
  feature/A merges first → V4__feature_a.sql
  feature/B rebases     → V5__feature_b.sql
```

### Rules for Team Development
1. **Never modify** a committed migration file — create a new one
2. **Never delete** migration files — use deprecation migrations
3. **Assign version** only at merge time, not during development (use timestamps)
4. **Test locally** with `./gradlew flywayMigrate` before PR
5. **Include rollback** plan in PR description for destructive changes

### Timestamp Versioning (avoids team conflicts)
```
V20240318142300__create_users.sql
V20240318160000__add_email_index.sql
```

## Safe Migration Patterns

### Adding a Column (safe)
```sql
-- Safe: nullable column with default
ALTER TABLE users ADD COLUMN phone VARCHAR(20) NULL;

-- Safe: non-null with default
ALTER TABLE users ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE';
```

### Renaming a Column (safe with dual-write)
```sql
-- Step 1: Add new column
ALTER TABLE users ADD COLUMN full_name VARCHAR(100);

-- Step 2: Deploy app code to write both columns
-- Step 3: Backfill data
UPDATE users SET full_name = name WHERE full_name IS NULL;

-- Step 4: Make new column non-null
ALTER TABLE users MODIFY COLUMN full_name VARCHAR(100) NOT NULL;

-- Step 5: Deploy app code to read new column only
-- Step 6: Drop old column
ALTER TABLE users DROP COLUMN name;
```

### Large Table Alterations
```sql
-- Use pt-online-schema-change or gh-ost for large tables
-- Never run blocking ALTER on tables > 1M rows in production
-- Example with pt-osc:
-- pt-online-schema-change --alter "ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'"
--   D=mydb,t=orders --execute
```

## CI/CD Integration

```yaml
# GitHub Actions
- name: Run Flyway migrations
  run: |
    ./gradlew flywayMigrate \
      -Dflyway.url=${{ secrets.DB_URL }} \
      -Dflyway.user=${{ secrets.DB_USER }} \
      -Dflyway.password=${{ secrets.DB_PASSWORD }}

- name: Validate migrations
  run: ./gradlew flywayValidate
```

## Checklist Before Each Migration

- [ ] Migration is idempotent or uses `IF NOT EXISTS`
- [ ] New columns are nullable or have defaults (no-downtime deploy)
- [ ] Indexes created with `CREATE INDEX` (not inside `ALTER TABLE`) for large tables
- [ ] Rollback script documented in PR
- [ ] Tested on a copy of production data
- [ ] Large table changes use online schema change tools
