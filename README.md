# cursor-skills

Personal Cursor Agent Skills, version-controlled. Install into your [user Agent Store](https://cursor.com) so they sync across machines and Cloud Agents.

## Layout

```
skills/
  clean-architecture-app/    # scaffold + layers for TypeScript CA monorepos
  clean-architecture-feature/
  …                          # other skills (Cloudflare, etc.)
```

Edit skills **here**, then run `./install.sh` to push them into the Agent Store.

## Install

```bash
./install.sh
```

Default target is this machine’s user Agent Store skills directory. Override:

```bash
CURSOR_AGENT_STORE_SKILLS="/path/to/files/skills" ./install.sh
```

The script **rsyncs** `skills/` into that directory (does not delete unrelated skills already in the store).

## New skill

1. Add `skills/<skill-name>/SKILL.md` with YAML frontmatter (`name`, `description`).
2. Run `./install.sh`.
3. Commit and push this repo.

## Source of truth

| Copy | Role |
| --- | --- |
| **This repo** | Git history, review, share |
| **Agent Store** `…/files/skills/` | What Cursor loads + account sync |

Do not treat the Agent Store as the only copy.

## License

Per-skill: check each folder (e.g. Cloudflare plugin skills may follow upstream terms).
