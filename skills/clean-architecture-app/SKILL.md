---
name: clean-architecture-app
description: >-
  Scaffolds a TypeScript Clean Architecture application as npm workspaces
  with inward-only dependencies (core, application, validation, infrastructure,
  optional client and UI). Use when creating a new Clean Architecture project,
  mapping a product onto Uncle Bob layers, or the user asks for use cases,
  ports and adapters, interactors, or a composition root.
---

# Clean Architecture app (TypeScript)

Build **product behavior first**, then **rings from the inside out**.
Do not implement a layer until the user is ready to discuss that layer.
Plan, show a small sample, then fill the rest.

Names such as `Customer` and `PlaceOrder` in [templates.md](templates.md) are
**shape examples**. Replace them with the product’s own concepts (`Workspace`,
`Issue`, … in the reference app).

See [layers.md](layers.md) for the import rule, [templates.md](templates.md)
for code shapes, and [scaffold.md](scaffold.md) for workspace files.

**Reference implementation:** Issue tracker (`@issue-tracker/*`, `docs/architecture.md`,
`AGENTS.md`). It is the canonical pattern for a **flat use-case facade**, **member
identity on command input**, **camelCase wire names**, **workspace-scoped SSE**, and
**MVVM UI**. Older quiz-style **nested `forHost` / `forPlayer`** facades remain valid
when roles expose disjoint command sets — see [layers.md](layers.md) identity.

## Hard rules

- Dependencies point **inward**. Inner packages never import outer ones.
- `core` has **no runtime dependencies** (no TypeBox, no other workspace packages).
  `src/domain/` must not import use-cases or events.
- Domain failures are `Error.name === "DomainError"` with product copy as
  `message` (`*_ERROR` constants next to the entity; `throwDomainError`).
- **Untrusted JSON** is parsed in a dedicated `validation` package (TypeBox).
  HTTP handlers, client, UI, and application must not import TypeBox or
  `validation`. Composition (only) wraps `execute` with `withParsedExecute`.
- Driving contracts live in `core`: `UseCase`, `Query`, exhaustive `USE_CASE_NAMES`.
  Use-case `name` is a **string literal on the type** (`UseCase<"createProject", …>`).
  **Wire names are camelCase** and match that literal (not kebab-case RPC aliases).
- When the product is live: `AppEvent` + `EventSubscriber` in `src/events.ts`.
  Subscribe by **aggregate/scope id** (`subscribe(workspaceId, listener)`), not by
  event type. Every event carries routing ids for that scope. No event factory helpers.
- Driven ports and interactors live in `application`. Delivery code (UI, HTTP
  handlers, dispatch, CLIs) must not import driven ports, `application`, or
  `validation` — even when those files sit in the `infrastructure` package.
- One `UseCase.execute` is one `UnitOfWork.run`. Side effects other clients
  should see run **after** that work commits. Serialize dispatch when the
  in-memory unit of work is not concurrent-safe.
- **Identity (pick one product pattern, do not mix on the wire):**
  - **Flat member commands (issue tracker):** `MemberUseCaseInput<T>` = `{ userId } & T`
    on member commands. `createWorkspace` (or equivalent) **mints** identity and has
    no `userId` on input. Infrastructure binds `RequestIdentity` from transport;
    application **`requireActingUser`** ensures `input.userId` matches that principal
    and refers to a persisted user. Dispatch and client pass **only** `{ name, input }`
    — no parallel actor parameter. HTTP may mirror `input.userId` in a header for
    request-scoped identity; the command body still carries `userId`.
  - **Role-nested facade (e.g. host vs player):** delivery resolves actor ids into
    `forHost` / `forPlayer` (or equivalent); session ports `requireHost()` /
    `requirePlayer()`; actor ids are **not** on every `Input` except minting use cases.
- Prefer factory functions `createX(deps)` over classes. Keep JSDoc on public
  types, ports, and use-case functions.
- Implement an in-memory adapter for every driven port before a real database
  or network I/O adapter.
- Import **concrete modules**. Do not add barrel `index.ts` re-export hubs.

## Package map

```
infrastructure  →  application  →  core
infrastructure  →  validation   →  core
client          ──────────────────►  core   (optional driving adapter)
ui              →  client ─────────►  core   (optional)
core → (no runtime dependencies)
validation → @sinclair/typebox
```

| Package | Responsibility |
| --- | --- |
| `core` | Handwritten domain (`src/domain/`), driving `UseCase` types (`src/use-cases/`), optional live events (`src/events.ts`) |
| `application` | Driven ports (repos, `UnitOfWork`, `RequestIdentity` or role sessions, ids, `EventPublisher`, clock) and interactors |
| `validation` | TypeBox schemas and `InputValidator` for untrusted use-case input JSON only |
| `infrastructure` | In-memory (+ optional SQL) adapters, drivers, composition root, transport-agnostic dispatch, HTTP/SSE |
| `client` | `createProductClient` (no fetch) + `createHttpProductClient` (HTTP + SSE) |
| `ui` | Presentation (e.g. MVVM: ViewModels → client). Imports `client` and `core` only |

`core` entry points: `@org/core` (events when live), `@org/core/domain/*`,
`@org/core/use-cases/*`. Do not re-export domain or use cases from events.

Inside `infrastructure`:

| Module | May import application / validation? |
| --- | --- |
| `composition/` | yes — the only place that wires interactors and `withParsedExecute` |
| `memory/`, `sqlite/`, `drivers/` | yes — they implement driven ports |
| `dispatch/`, `http/` | **no** — they take `ProductApp` / flat `ProductUseCases` |

Omit `client` / `ui` when there is no frontend. Omit events when nothing is live.
Omit `validation` only if there is no external JSON boundary (rare).

## Driving facades (when live + UI)

| Surface | Where | Shape |
| --- | --- | --- |
| `ProductUseCases` | core | **Prefer flat:** one property per public use case (`createProject`, `getProjectView`, …). Use nested `forHost` / `forPlayer` only when roles have disjoint command sets. |
| `ProductApp` | infrastructure composition | `ProductUseCases` + shared `events` (in-process server/tests) |
| `ProductClient` | client | extends `ProductUseCases` + `events` (browser/remote) |

The composition root **requires** an injected event bus
(`EventPublisher` & `EventSubscriber`). Callers pass the **same** instance to
HTTP/SSE and to `createProductApp({ events })`.

Typical wiring (issue tracker):

```ts
const events = createInMemoryEventBus();
const app = createIssueTrackerApp({ events, ...optionalSqlitePersistence });
createIssueTrackerHttpServer({ app, staticDir: "packages/ui/dist" });
// browser:
const client = createHttpIssueTrackerClient({ baseUrl });
```

Default HTTP (when used): `POST /api/use-cases` with `{ name, input }` (camelCase
`name`); member session via header derived from `input.userId` when present;
`GET /api/events/:workspaceId` as SSE. Status codes stay in the HTTP layer.

## Workflow (stop after each step unless asked to continue)

```
- [ ] 1. Product spec (behavior, not frameworks)
- [ ] 2. Scaffold packages + agent docs + architecture note
- [ ] 3. Domain entities (handwritten types in core)
- [ ] 4. Driving use cases (+ events if live)
- [ ] 5. Driven ports in application
- [ ] 6. Sample interactors → review → remainder
- [ ] 7. Interactor tests with mocked ports
- [ ] 8. In-memory adapters
- [ ] 9. Delivery adapters (dispatch, then HTTP/CLI/…)
- [ ] 10. Driving client for that delivery (if there is a UI or external caller)
- [ ] 11. Remaining drivers (ids, clock, RequestIdentity, event bus, …)
- [ ] 12. Composition root (+ validation wrappers)
- [ ] 13. Optional second persistence (SQLite, …)
- [ ] 14. UI last (MVVM: viewmodels, hooks, views; subscribe + re-query)
```

Clock ports are required when the domain records timestamps (issues, comments).

### 1. Product spec

Write what the software **does for users**. Do not start from a framework’s data model, SDK, or live-query API.

### 2. Scaffold

Follow [scaffold.md](scaffold.md): npm workspaces, Node 22+, TypeScript `strict` +
`NodeNext` + project references, Vitest with source aliases. Empty packages whose
`package.json` `exports` encode concrete subpaths. Cursor rules: always-apply
dependency rule; glob-scoped import examples per package. `AGENTS.md` plus
`docs/product.md`, `docs/domain.md`, `docs/architecture.md`, `docs/user-stories.md`,
and `docs/ui.md` when there is a browser UI — **before** filling folders.

### 3. Domain

One module per concept under `core/src/domain/`. **Handwritten** types and unions.
Limits and user-facing error copy as named constants. `core/domain/error.ts` holds
`domainError` / `throwDomainError` / `isDomainError`. Domain helpers enforce
invariants — no I/O. Ids are opaque domain values, not framework document metadata.

### 4. Driving use cases

Each command is `UseCase<Name, Input, Output>` with `Name` a camelCase string literal.

- `Input` / `Output` are JSON-shaped DTO types defined in core (handwritten).
- Member commands: `MemberUseCaseInput<{ …fields }>` includes `userId`.
- Reads may take scoped ids (`workspaceId`, `projectId`, …) on `Input`.
- `name` is the registry key; delivery routes on it exhaustively.
- Credential-minting create cases **return** the identity delivery will store.
- Query **views** (`WorkspaceView`, `ProjectView`, …) are DTOs in core, rebuilt from
  persisted state on every call so refresh/reconnect catches up.

Define `UseCaseName` and `USE_CASE_NAMES` with `satisfies Record<UseCaseName, true>`.

Query use cases are one-shot. If the UI must stay current, subscribe to the
scope id and re-run the query (filter events in the ViewModel — e.g. only
`project-changed` for the open project). Do not invent implicit reactivity in the domain.

If events exist: typed `AppEvent` union in `core/events.ts`; publish object literals
after `run` resolves. Skip an event when no other client needs to refresh.

### 5. Driven ports

Repositories under `application/ports/repositories/`, plus `UnitOfWork`,
`RequestIdentity` (or role session ports), ids, clock, outbound gateways.
Persistence methods take an opaque `TransactionContext` first.

Do not nest use cases. Compose ports inside a single `run`.

### 6–7. Interactors and tests

`createCreateProject(deps): CreateProject`. Validate with domain helpers and
`requireActingUser` (or role session); persist inside `uow.run`; publish after it
resolves.

Implement two or three interactors and wait for review. Tests mock every port.
Assert identity checks, `tx` forwarding, persistence arguments, post-commit
publish, and domain errors.

### 8. In-memory adapters

One in-memory implementation per driven port, tests beside the adapter. The
memory `UnitOfWork` copy-on-writes tables and commits only if `work` resolves.
It is not safe for overlapping `run` calls.

### 9–10. Delivery

The delivery mechanism is not the architecture.

- **Dispatch** (`createUseCaseDispatcher`): `name` + JSON `input` only — no HTTP,
  no `Actor` side channel on the issue-tracker model. Exhaustive `switch` on
  `UseCaseName`. Mutex-serialize `execute`. Source must not import `node:http`
  or `application`.
- **HTTP** (if used): `createProductHttpServer({ app: ProductApp })` runs RPC
  through dispatch on `app` and streams SSE from `app.events`. Bind
  `RequestIdentity` per request from headers when using member commands.
- **Client**: `createProductClient(transport)` in `client.ts` (no fetch, no URLs).
  `createHttpProductClient` in `http-client.ts` implements `UseCaseTransport`.
  Must not import `application`, `infrastructure`, or `validation`.

Input validation: `withParsedExecute(validator, useCase)` at the **composition
root** only.

### 11–12. Wire up

The composition root is the only place that constructs adapters, interactors,
validation wrappers, and the `ProductApp` facade. Optional deps override ports
in tests. Tests boot with in-memory ports and an injected in-memory event bus.

### 13–14. Second persistence, then UI

A database adapter implements the **same** ports (`createSqlitePersistence()` spread
into `createProductApp`). Presentation uses ViewModels over `client`; subscribe to
`events` for `workspaceId`, then background-refresh the active query. Screen state
(draft title, form open) stays in the ViewModel or view — not server-driven navigation.

## Agent docs in the new repo

- `AGENTS.md` — packages, inward imports, workflow step, identity model, out of scope
- Product, domain, architecture, user stories, and UI plan when applicable
- Cursor rules: always-apply dependency rule; per-package import examples

Product-specific out-of-scope lists belong in **that repo’s** `AGENTS.md`, not in this skill.

## Do not

- Implement a ring before it has been discussed
- Put TypeBox or `Static<>` types in `core` domain or use-case modules
- Put repositories or other driven ports in `core/use-cases`
- Trust `userId` on input without `requireActingUser` (or equivalent) against `RequestIdentity`
- Add a second actor channel on the wire (`forMember` RPC) separate from `Input` when using the flat member model
- Use kebab-case use-case wire names when the type literal is camelCase
- Subscribe to live events by type instead of by scope id
- Publish or send notifications inside an uncommitted unit of work
- Import `application` or `validation` from HTTP handlers or dispatch
- Put fetch, headers, or URLs in `client.ts` (those belong in `http-client.ts`)
- Import `application`, `infrastructure`, or `validation` from UI
- Start a database or UI before in-memory ports exist
- Copy a framework’s document ids or reactive APIs into the domain
- Treat HTTP resource design (REST nouns, GraphQL) as the domain model
- Add barrel `index.ts` files that re-export whole packages
