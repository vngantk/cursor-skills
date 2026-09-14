# cursor-skills

Personal Cursor Agent Skills, version-controlled. Install into your [user Agent Store](https://cursor.com) so they sync across machines and Cloud Agents.

## Skills

| Skill | Purpose |
| --- | --- |
| `clean-architecture-app` | Scaffold a TypeScript Clean Architecture monorepo (workspaces, layers, workflow) |
| `clean-architecture-feature` | Add one feature across domain → use case → adapters → delivery → UI |

## Layout

```
skills/
  clean-architecture-app/    # SKILL.md + layers.md, templates.md, scaffold.md
  clean-architecture-feature/
validate-skills.sh
install.sh
```

Edit skills **here**, then run `./validate-skills.sh` and `./install.sh`.

## Install

```bash
./install.sh
```

`install.sh` discovers your Agent Store `files/skills` directory when exactly one exists (macOS and Linux Cursor paths). Override when needed:

```bash
CURSOR_AGENT_STORE_SKILLS="/path/to/files/skills" ./install.sh
```

The script **rsyncs** `skills/` into that directory. It does **not** delete other skills already in the store; remove vendored copies manually in the Agent Store if you no longer want them.

## Validate

```bash
./validate-skills.sh
```

Checks each `skills/*/SKILL.md` for YAML frontmatter, folder/name alignment, description length, and relative links from `SKILL.md`.

## New skill

1. Add `skills/<skill-name>/SKILL.md` with YAML frontmatter (`name`, `description`).
2. Run `./validate-skills.sh` and `./install.sh`.
3. Commit and push this repo.

## Source of truth

| Copy | Role |
| --- | --- |
| **This repo** | Git history, review, share |
| **Agent Store** `…/files/skills/` | What Cursor loads + account sync |

Do not treat the Agent Store as the only copy.
