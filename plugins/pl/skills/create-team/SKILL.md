---
name: create-team
description: 'Guides the user through creating a Claude Code Agent Team using available role-based agents. Handles team composition, task partitioning, file ownership assignment, and spawn command generation.'
---

# Create Agent Team

> **Experimental Feature**: Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable.

You are helping the user design and launch a Claude Code Agent Team. Follow these steps to create an effective team composition.

---

## Step 1 — Enable Agent Teams

First, verify the environment flag is enabled. If not, add it to `.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Or enable temporarily in the current session:
```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

---

## Step 2 — Understand the User's Task

Ask the user (if not already stated):
1. **What is the overall goal?** (e.g., "Build a REST API with frontend and tests")
2. **What are the independent workstreams?** (e.g., backend API, frontend UI, database schema, test suite)
3. **Are there 3+ parallel streams of work?** If fewer than 3, recommend using subagents instead.

### Decision Rule

| Condition | Recommendation |
|-----------|----------------|
| 3+ independent parallel streams | ✅ Use Agent Teams |
| Workers need to share findings or challenge each other | ✅ Use Agent Teams |
| Single focused task | ❌ Use Subagent instead |
| Same files being edited by multiple workers | ❌ Use Subagent (sequential) |
| Cost-sensitive, simple task | ❌ Use Subagent instead |

---

## Step 3 — Select Team Members

Choose from the available agents in this framework. Each agent has a specific expertise:

| Agent | Role | Best Used For |
|-------|------|---------------|
| `backend-developer` | Senior Backend Engineer | API design, Spring Boot, NestJS, FastAPI, database integration |
| `frontend-developer` | Senior Frontend Engineer | React, Next.js, Vue, UI components, state management |
| `dba` | Database Administrator | Schema design, query optimization, migrations, indexing |
| `qa` | QA Engineer | Test plans, Playwright E2E, unit/integration tests, automation |
| `ui-ux-designer` | UI/UX Designer | Design systems, component design, accessibility, UX flows |
| `pm` | Product Manager | PRDs, user stories, feature requirements, prioritization |
| `planner` | Service Planner (기획자) | Service specs, user flows, wireframes, business logic docs |
| `pl` | Project Lead / Tech Lead | Architecture, code review standards, task breakdown, coordination |

### Team Size Guidelines
- **3–5 teammates** is optimal for most workflows
- **5–6 tasks per teammate** keeps everyone productive
- More teammates ≠ faster results (coordination overhead increases)
- Start small — scale only when genuinely needed

---

## Step 4 — Partition Work by File Ownership

**Critical Rule**: Each teammate MUST own distinct files. No two teammates can edit the same file.

### How to Partition

1. List all files/modules that will be created or modified
2. Group them into independent clusters
3. Assign each cluster to one teammate
4. Ensure zero overlap between clusters

### Example Partition (Full-Stack Feature)

```
Teammate A (backend-developer):
  - src/main/java/com/example/api/UserController.java
  - src/main/java/com/example/service/UserService.java
  - src/main/java/com/example/repository/UserRepository.java

Teammate B (frontend-developer):
  - src/components/UserProfile.tsx
  - src/pages/users/[id].tsx
  - src/hooks/useUser.ts

Teammate C (dba):
  - src/main/resources/db/migration/V1__create_users.sql
  - src/main/resources/db/migration/V2__add_user_indexes.sql

Teammate D (qa):
  - src/test/java/com/example/api/UserControllerTest.java
  - tests/e2e/user-profile.spec.ts
```

---

## Step 5 — Define Team Patterns

Choose the pattern that fits the work:

### Pattern A: Parallel Implementation Team
- **Use when**: Independent feature streams (most common)
- **Structure**: Each teammate implements their own module
- **Communication**: Minimal — work independently, share a task list
- **Lead**: PL monitors progress, reassigns if blocked

### Pattern B: Quality Review Team
- **Use when**: Code quality, security, and test coverage are priorities
- **Structure**:
  - Teammate A: Implements the feature
  - Teammate B: Writes tests
  - Teammate C: Reviews code quality, security, performance
  - Lead (PL): Synthesizes findings, executes fixes sequentially

### Pattern C: Research Team
- **Use when**: Technology selection, architecture decisions, deep investigation
- **Structure**: 3–5 researchers, each assigned different sources/perspectives
  - One teammate plays Devil's Advocate to challenge findings
- **Lead (PL)**: Synthesizes into a final report

---

## Step 6 — Generate Team Spawn Commands

Based on the selected teammates and partitioned work, generate the spawn commands.

### Template

```
/team <N> "
You are [ROLE] in an Agent Team led by the Project Lead.

## Your Assignment
[Specific task description for this teammate]

## Your Files (you own these exclusively — do NOT touch files assigned to other teammates)
[List of files this teammate owns]

## Shared Context
[Brief description of what other teammates are doing]

## Completion
When done, update the task list and signal completion via TaskUpdate.
"
```

### Example: 3-Person Full-Stack Team

```
/team 3 "
Teammate 1 (backend-developer): Build the User CRUD REST API
  Files: src/main/java/com/example/api/UserController.java, UserService.java, UserRepository.java
  Task: Implement GET /users, POST /users, PUT /users/{id}, DELETE /users/{id}

Teammate 2 (frontend-developer): Build the User Management UI
  Files: src/components/UserList.tsx, UserForm.tsx, src/pages/users/index.tsx
  Task: Implement user list page, create/edit form, API integration with fetch hooks

Teammate 3 (qa): Write comprehensive tests
  Files: src/test/java/com/example/UserControllerTest.java, tests/e2e/users.spec.ts
  Task: Unit tests for service layer, MockMvc tests for API, Playwright E2E for user flows
"
```

---

## Step 7 — Set Up Coordination

### Recommended Settings

Add to `.claude/settings.json` for hook-based coordination:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "hooks": {
    "TeammateIdle": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Teammate idle — check for blocked tasks or reassignment needs'"
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Task completed — validate deliverables before marking done'"
          }
        ]
      }
    ]
  }
}
```

### Inter-Agent Communication
- Use **Mailbox system** (via `SendMessage` tool) when teammates need to share findings
- Use **TaskCreate/TaskUpdate** to track progress across teammates
- PL (lead) should monitor `TaskList` to detect blockers

---

## Step 8 — Final Checklist Before Launch

Before spawning the team, confirm:

- [ ] `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set
- [ ] Each teammate has a **distinct set of files** (zero overlap)
- [ ] Each teammate has **5–6 tasks** to avoid idle time
- [ ] Team size is **3–5 teammates** (not more)
- [ ] Shared context (what others are doing) is in each spawn prompt
- [ ] A coordination mechanism (TaskList or Mailbox) is defined
- [ ] The PL role is assigned to oversee and synthesize

---

## Quick Reference: Anti-Patterns to Avoid

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Two teammates editing same file | Merge conflicts, lost work | Re-partition files |
| 6+ teammates | Coordination overhead kills speed | Reduce to 3–5 |
| No file ownership specification | Teammates block each other | Explicitly list files per agent |
| All tasks in one teammate's prompt | Uneven load | Distribute ~equal number of tasks |
| No completion signal defined | Lead doesn't know when done | Add TaskUpdate to each teammate's prompt |
