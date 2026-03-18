# my_cc_team_framework

A curated Claude Code marketplace with role-based AI agents and curated skills for development teams.

Each plugin includes a **specialized agent** (defining role, responsibilities, and workflow) paired with **relevant skills** sourced from the [skills.sh](https://skills.sh) ecosystem.

---

## Installation

### 1. Add this marketplace

Run this in your terminal:

```bash
claude marketplace add github:pyb8527/my_cc_team_framework
```

### 2. Install plugins inside a Claude Code session

Open Claude Code, then use the `/plugin` slash command:

```
/plugin install backend-developer@my_cc_team_framework
/plugin install frontend-developer@my_cc_team_framework
/plugin install dba@my_cc_team_framework
/plugin install qa@my_cc_team_framework
/plugin install ui-ux-designer@my_cc_team_framework
/plugin install pm@my_cc_team_framework
/plugin install planner@my_cc_team_framework
/plugin install pl@my_cc_team_framework
/plugin install understand-repo@my_cc_team_framework
```

Or open the plugin browser with `/plugin` and find them in the **Discover** tab.

---

## Plugins

| Plugin | Agent | Skills Included |
|--------|-------|-----------------|
| [understand-repo](./plugins/understand-repo) | — | Full codebase analysis: architecture, modules, DB, API, how to run |
| [backend-developer](./plugins/backend-developer) | Senior Backend Dev | java-springboot, kotlin-springboot, springboot-patterns, springboot-security, springboot-tdd, create-spring-boot-java-project |
| [frontend-developer](./plugins/frontend-developer) | Senior Frontend Dev | nextjs-developer, nextjs-react-typescript, next-best-practices, vercel-react-best-practices |
| [dba](./plugins/dba) | Database Administrator | supabase-postgres-best-practices, mysql-best-practices, redis-best-practices |
| [qa](./plugins/qa) | QA Engineer | webapp-testing, frontend-testing-best-practices, playwright-cli |
| [ui-ux-designer](./plugins/ui-ux-designer) | UI/UX Designer | frontend-design, canvas-design, theme-factory, brand-guidelines |
| [pm](./plugins/pm) | Product Manager | doc-coauthoring, pptx, docx, internal-comms |
| [planner](./plugins/planner) | 기획자 / Service Planner | doc-coauthoring, pptx, docx, internal-comms |
| [pl](./plugins/pl) | Project Lead / Tech Lead | create-team |

---

## Plugin Structure

Each plugin follows the standard Claude Code plugin format:

```
plugins/<role>/
├── .claude-plugin/
│   └── plugin.json        # Plugin metadata
├── agents/
│   └── <role>.md          # Agent definition (role, responsibilities, workflow)
└── skills/
    └── <skill-name>/
        └── SKILL.md       # Skill sourced from skills.sh
```

---

## Skills Sources

| Skill | Source |
|-------|--------|
| java-springboot | [github/awesome-copilot](https://github.com/github/awesome-copilot) |
| kotlin-springboot | [github/awesome-copilot](https://github.com/github/awesome-copilot) |
| create-spring-boot-java-project | [github/awesome-copilot](https://github.com/github/awesome-copilot) |
| springboot-patterns | [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) |
| springboot-security | [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) |
| springboot-tdd | [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) |
| nextjs-developer | [jeffallan/claude-skills](https://github.com/jeffallan/claude-skills) |
| nextjs-react-typescript | [Mindrally/skills](https://github.com/Mindrally/skills) |
| next-best-practices | [vercel-labs/next-skills](https://github.com/vercel-labs/next-skills) |
| vercel-react-best-practices | [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) |
| supabase-postgres-best-practices | [supabase/agent-skills](https://github.com/supabase/agent-skills) |
| mysql-best-practices | [Mindrally/skills](https://github.com/Mindrally/skills) |
| redis-best-practices | [Mindrally/skills](https://github.com/Mindrally/skills) |
| webapp-testing | [anthropics/skills](https://github.com/anthropics/skills) |
| frontend-testing-best-practices | [sergiodxa/agent-skills](https://github.com/sergiodxa/agent-skills) |
| playwright-cli | [microsoft/playwright-cli](https://github.com/microsoft/playwright-cli) |
| frontend-design | [anthropics/skills](https://github.com/anthropics/skills) |
| canvas-design | [anthropics/skills](https://github.com/anthropics/skills) |
| theme-factory | [anthropics/skills](https://github.com/anthropics/skills) |
| brand-guidelines | [anthropics/skills](https://github.com/anthropics/skills) |
| doc-coauthoring | [anthropics/skills](https://github.com/anthropics/skills) |
| pptx | [anthropics/skills](https://github.com/anthropics/skills) |
| docx | [anthropics/skills](https://github.com/anthropics/skills) |
| internal-comms | [anthropics/skills](https://github.com/anthropics/skills) |
| create-team | custom |

---

## Adding More Plugins

1. Create a new directory under `plugins/<name>/`
2. Add `.claude-plugin/plugin.json`, `agents/<name>.md`, and `skills/` as needed
3. Register the plugin in `.claude-plugin/marketplace.json`

Contributions welcome!
