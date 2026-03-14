---
name: understand-repo
description: This skill should be used when the user asks to "understand this repo", "explain the codebase", "analyze the project", "give me an overview", "what does this project do", "understand the architecture", "explain the structure", "onboard me to this repo", "map the codebase", or wants a comprehensive breakdown of how a repository works.
version: 1.0.0
---

# Understand Repo

Perform a thorough, structured analysis of the current repository and produce a complete, developer-ready overview. This skill is meant to onboard someone from zero to productive as fast as possible.

## Approach

Work through the following phases in order. Run file searches and reads in parallel where possible. Be concise within each section — prioritize signal over exhaustiveness.

---

## Phase 1 — Project Identity

Start by answering: *What is this project, and who is it for?*

1. Read `README.md` (root level). Extract: purpose, target users, high-level features.
2. Check for `CLAUDE.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, `docs/` — read if present.
3. Identify the **project type**: web app, CLI tool, library/SDK, microservice, monorepo, data pipeline, mobile app, etc.
4. Identify **primary language(s)** and **runtime** from file extensions and config files.

---

## Phase 2 — Tech Stack Detection

Scan for the following files and extract key information from each that exists:

| File | What to extract |
|------|----------------|
| `package.json` | framework, major deps, scripts |
| `pyproject.toml` / `setup.py` / `requirements.txt` | Python deps, entry points |
| `Cargo.toml` | Rust crates, features |
| `go.mod` | Go module name, major deps |
| `pom.xml` / `build.gradle` | Java/Kotlin framework, plugins |
| `Gemfile` | Ruby gems, Rails version |
| `pubspec.yaml` | Flutter/Dart packages |
| `Dockerfile` / `docker-compose.yml` | base images, services, ports |
| `.env.example` / `.env.template` | required environment variables |
| `Makefile` | available targets and their purposes |

Summarize:
- **Frontend**: framework, UI library, bundler, styling
- **Backend**: language, framework, API style (REST / GraphQL / gRPC / tRPC / etc.)
- **Infrastructure**: containerization, cloud provider hints, IaC tools
- **Notable libraries**: auth, ORM, testing, caching, queues

---

## Phase 3 — Directory Architecture

Run a directory-level scan (depth 2-3). For each top-level directory, infer its role. Map the layout like this:

```
project/
├── src/           → Application source code
│   ├── api/       → HTTP route handlers
│   ├── services/  → Business logic layer
│   ├── models/    → Data models / entities
│   └── utils/     → Shared helpers
├── tests/         → Test suite
├── scripts/       → Dev/build/deploy scripts
├── docs/          → Documentation
└── infra/         → Infrastructure as code
```

Identify:
- Where is the **entry point**? (e.g., `main.ts`, `app.py`, `index.js`, `cmd/main.go`, `lib.rs`)
- Is this a **monorepo**? If so, list each package/app and its role.
- Are there clear **layer boundaries**? (e.g., controllers → services → repositories)

---

## Phase 4 — Core Module Breakdown

Pick the 5–10 most important modules/directories. For each:

1. Read 1–3 key files to understand what it does.
2. Describe in 2–3 sentences: responsibility, inputs/outputs, key abstractions.

Focus on modules that are: most referenced, largest, or clearly central to the domain.

---

## Phase 5 — Data Layer

Look for:
- **ORM models**: `models/`, `entities/`, `schema/`, Prisma `.prisma` files, SQLAlchemy models, ActiveRecord, Hibernate entities
- **Migrations**: `migrations/`, `db/migrate/`, Flyway/Liquibase scripts
- **Raw SQL**: `.sql` files
- **Database config**: connection strings, DB type hints in env vars or config files
- **NoSQL**: Mongoose schemas, DynamoDB table definitions, Firestore rules

Produce:
- Estimated **database type** (PostgreSQL, MySQL, MongoDB, SQLite, Redis, etc.)
- **Entity list** with key fields (infer from models/migrations, not just filenames)
- **Key relationships** (foreign keys, references between entities)
- Any **caching layer** (Redis, Memcached, in-memory)

If no persistent data layer is found, note that explicitly.

---

## Phase 6 — API Surface

If the project exposes an API:

1. Find route definitions (`routes/`, `controllers/`, `handlers/`, decorators like `@Get`, `@app.route`)
2. List key endpoints grouped by resource: method, path, brief purpose
3. Note authentication mechanism (JWT, session, API key, OAuth)
4. Check for API docs: `swagger.yaml`, `openapi.json`, GraphQL schema

---

## Phase 7 — How to Run

Find and summarize all the ways to run the project:

1. **Install dependencies**: `npm install`, `pip install -r requirements.txt`, etc.
2. **Environment setup**: required env vars from `.env.example`
3. **Database setup**: migration commands, seed commands
4. **Start development**: dev server command, hot reload info
5. **Run tests**: test command, coverage command
6. **Build for production**: build command, output artifact
7. **Docker**: `docker-compose up` or equivalent

Present this as an ordered "Getting Started" checklist a new developer can follow immediately.

---

## Phase 8 — Testing Strategy

- **Test framework**: Jest, pytest, RSpec, Go test, JUnit, etc.
- **Test types present**: unit, integration, e2e, snapshot
- **Coverage tooling**: Istanbul, coverage.py, etc.
- **Test file locations and naming conventions**
- **CI integration**: GitHub Actions, GitLab CI, CircleCI — read `.github/workflows/` or equivalent

---

## Phase 9 — Key Patterns & Conventions

Note any patterns that a developer needs to know to contribute effectively:

- **Coding style**: linting/formatting tools (ESLint, Prettier, Black, Rustfmt)
- **Commit conventions**: Conventional Commits, custom prefix requirements
- **Branching strategy**: hints from PR templates or CONTRIBUTING.md
- **Error handling patterns**: custom error classes, global handlers
- **Dependency injection**: DI containers, service providers
- **Config management**: how env-specific config is managed
- **State management** (frontend): Redux, Zustand, Pinia, etc.

---

## Output Format

Produce a structured report with the following sections (use markdown headers):

```
## Project Overview
## Tech Stack
## Architecture Map
## Core Modules
## Data Layer
## API Surface          ← omit if no API
## How to Run
## Testing
## Key Conventions
## Open Questions       ← list anything ambiguous or worth investigating further
```

Keep each section tight. Use tables, bullet lists, and code blocks freely. Avoid padding and filler. The goal is a document a senior engineer could use to start contributing within an hour.

---

## Important Notes

- **Infer, don't guess**: if you can't find evidence for something, say "not found" rather than speculating.
- **Prioritize reading over listing**: reading 3 important files beats listing 30 filenames.
- **Flag what's unusual**: if you see non-standard patterns, note them explicitly.
- **Surface risks**: deprecated dependencies, missing tests, insecure defaults — mention them briefly.
