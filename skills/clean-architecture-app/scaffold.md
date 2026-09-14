# Scaffold

Create this layout **empty** (docs + package boundaries) before domain code.
Replace `@org` and `product-name` with the product’s names.

## Layout

```
package.json
tsconfig.json
tsconfig.base.json
tsconfig.test.json
vitest.config.ts
AGENTS.md
docs/product.md
docs/domain.md
docs/architecture.md
docs/user-stories.md
docs/ui.md                              (if browser UI)
.cursor/rules/dependency-rule.mdc          (alwaysApply)
.cursor/rules/*-imports.mdc                (per package)
packages/core/package.json
packages/application/package.json
packages/validation/package.json
packages/infrastructure/package.json
packages/client/package.json               (optional)
packages/ui/package.json                   (optional)
scripts/start.mjs                          (optional: dev server + STATIC_DIR)
```

No `index.ts` barrels. Tests beside source (`foo.ts` / `foo.test.ts`).

## Root

Node `>=22`. npm workspaces `packages/*`. Scripts: `build` (`tsc -b`), `clean`,
`test` (`vitest run`), `test:coverage`, `dev:ui`, `dev:all`, `build:ui`.

`start` / `dev`: build, create event bus, `createProductApp({ events, …persistence })`,
`createProductHttpServer({ app, staticDir? })`. Env: `DATABASE_PATH` (SQLite),
`STATIC_DIR` (SPA dist), `PORT` / `HOST`.

## UI package (optional)

```
packages/ui/src/
  app/           # router, client factory, session (e.g. userId in URL + localStorage)
  viewmodels/    # MVVM: load/refresh, commands, SSE subscribe
  hooks/         # useViewModel, feature hooks
  views/         # route pages
  components/ui/ # design system (e.g. shadcn)
```

UI imports **client + core only**. Live bar: subscribe to `workspaceId`, filter
events, background `refresh()` without full-page loading.

## Package exports

Concrete subpaths — see issue tracker `package.json` files for a full example.

## Vitest

Alias workspace packages to `packages/<pkg>/src/…ts`. `npm test` does not require `tsc -b`.

## Cursor rules

Always-apply dependency rule: inward graph, no barrels, one `execute` = one `run`,
identity model documented in `AGENTS.md`, do not implement a ring ahead of the workflow step.

Per-package glob rules:

- core: no TypeBox, no outer packages; domain must not import use-cases or events
- application: core only; ports take `tx` first; no nested use cases
- validation: core + TypeBox only
- infrastructure: application + core + validation; **HTTP and dispatch must not import application or validation**
- client: core only; `client.ts` has no fetch
- ui: client + core only

## Agent docs

`AGENTS.md`: package table, flat vs nested facade choice, member identity rules,
numbered workflow, **this product’s** out-of-scope list, product vocabulary.

`docs/architecture.md`: graph, transactions, events, composition, delivery split.

## Encapsulation tests (once packages exist)

- Validation: TypeBox only in that package’s `package.json`
- Dispatch: no `node:http` or `application` import
- Client `client.ts`: no `fetch`, `/api/`, or header names
