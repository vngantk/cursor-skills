# Layers

## Dependency rule

Source code dependencies point toward `core`. Frameworks, databases, HTTP,
and UI are outer.

```
infrastructure  →  application  →  core
infrastructure  →  validation   →  core
client          ──────────────────►  core
ui              →  client ─────────►  core
core → (no runtime dependencies)
validation → @sinclair/typebox
```

## Driving vs driven

| Kind | Called by | Interface lives in |
| --- | --- | --- |
| Driving | Delivery (UI, HTTP, CLI) calling in | `core` (`UseCase`, `Query`, optional `EventSubscriber`) |
| Driven | Interactor calling out | `application` (repositories, `UnitOfWork`, `RequestIdentity` or role sessions, `EventPublisher`, clock, ids) |

One infrastructure object may implement both publisher and subscriber on the
same in-memory bus.

## Validation ring

| Concern | Layer |
| --- | --- |
| Handwritten domain and use-case DTO types | `core` |
| TypeBox schemas mirroring **untrusted input** | `validation` |
| `createInputValidator` / `withParsedExecute` | `validation` |
| Wrapping interactors before exposing `execute` | composition root (`infrastructure`) |

Domain invariants stay in core helpers and interactors — not in validation alone.
Delivery must not import `@org/validation` or TypeBox.

## Transactions

`TransactionContext` is opaque. `UnitOfWork.run` is the transaction.

The in-memory `UnitOfWork` copy-on-writes shared tables and promotes the copy
only if `work` resolves. It is **not** safe for concurrent `run` calls.
Dispatch serializes `execute`.

`RequestIdentity` is **not** transaction-scoped; it reflects the current HTTP
request (or test override).

## Identity (two supported patterns)

Pick one per product. The issue tracker uses **flat member commands**.

### A — Flat member facade (issue tracker)

| Piece | Where | Role |
| --- | --- | --- |
| `MemberUseCaseInput<T>` | core use-cases | `{ userId } & T` on member commands |
| `RequestIdentity` | application port | `requireCurrentUserId()` from transport |
| `requireActingUser` | application interactor helper | Ensures `input.userId` matches identity and user exists |
| Minting use case | e.g. `createWorkspace` | No `userId` on input; output returns new `userId` |
| Wire | dispatch / client / HTTP body | `{ name, input }` only — camelCase `name` |
| HTTP session | infrastructure | Header (e.g. `x-issue-user-id`) set from `input.userId` in the HTTP client; handler binds `RequestIdentity` for the request |

Do **not** add `forMember` nesting on the client or a parallel actor argument to
`dispatch.execute` when using this model.

### B — Role-nested facade (e.g. host vs player)

| Piece | Where | Role |
| --- | --- | --- |
| `Actor` | core use-cases | Optional ids delivery resolved from headers |
| `HostSession` / `PlayerSession` | application | `requireHost()` / `requirePlayer()` |
| `ProductUseCases.forHost(…)` | core + composition | Binds session per role |
| Wire | dispatch | `execute(name, input, actor)` — actor ids as headers, not on most `Input` |

Credential-minting create/join cases return ids delivery will store.

## Live events

| Rule | Detail |
| --- | --- |
| Subscribe | `subscribe(workspaceId, listener)` — or product scope id |
| Routing | Every `AppEvent` includes scope ids; bus fans out per subscription |
| UI | Re-run query use cases; filter events in ViewModels (`project-changed` + `projectId`, etc.) |
| Publish | After `UnitOfWork.run` resolves, object literal |
| Skip | No event when no other client needs to refresh |

Do not subscribe by event type only. Payload means “something changed”; truth is
in persisted state via queries.

## Infrastructure split

| Path | Imports | Owns |
| --- | --- | --- |
| `composition/` | application, validation, core, adapters | `createProductApp({ events, … })` |
| `memory/`, `sqlite/`, `drivers/` | application ports they implement | Repos, UoW, ids, clock, event bus, `RequestIdentity` |
| `dispatch/` | **core only** (+ facade types) | `execute(name, input)`; mutex; exhaustive switch |
| `http/` | **core** + dispatch types | RPC, SSE, static files, status mapping |

HTTP takes `{ app: ProductApp }`. It must not construct interactors.

## UI (when present)

| Concern | Layer |
| --- | --- |
| ViewModels (`load`, commands, SSE refresh) | `ui/viewmodels` |
| Thin hooks (`useViewModel`) | `ui/hooks` |
| Pages / components | `ui/views`, `ui/components` |
| API access | `client` only |

Delivery must not import application or infrastructure.

## What lives where

| Concern | Layer |
| --- | --- |
| Invariants, ids, `*_ERROR`, `throwDomainError` | `core` domain |
| Use-case DTOs, views, `name`, `IssueTrackerUseCases` | `core` use-cases |
| `AppEvent` + `EventSubscriber` | `core` (`events.ts`) |
| Orchestration, `requireActingUser`, membership checks | application interactors |
| Repos, `UnitOfWork`, `RequestIdentity`, `EventPublisher` | application ports |
| SQL, memory tables, HTTP, SSE | infrastructure |
| `ProductApp` | infrastructure `composition/` |
| `IssueTrackerClient` + transport | `client` |
| Layout, MVVM state | `ui` |

## Composition and delivery

- Inject `events: EventPublisher & EventSubscriber` into `createProductApp`.
- Return `ProductApp extends ProductUseCases { events }`.
- HTTP: `createIssueTrackerHttpServer({ app, staticDir? })`.
- Client: flat `createIssueTrackerClient(transport)`; HTTP in `http-client.ts`.
- Catch-up on reconnect = query use cases against persistence, not server RAM.
