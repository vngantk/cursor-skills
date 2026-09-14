---
name: clean-architecture-feature
description: >-
  Adds one feature to a TypeScript Clean Architecture codebase by walking
  domain → use-case contract → interactor → driven port → adapter → delivery
  → UI. Use when adding a use case, entity, repository method, or application
  event to an existing core / application / validation / infrastructure workspace.
---

# Add a Clean Architecture feature

Touch rings from the inside out. Skip a ring only when it already exists.
Use the product’s language (`Workspace`, `Issue`, … in the issue tracker).

For package boundaries and code shapes, read the `clean-architecture-app`
skill files `layers.md` and `templates.md`.

**Reference:** `@issue-tracker/*` — flat `IssueTrackerUseCases`, camelCase names,
`MemberUseCaseInput`, `requireActingUser`, workspace-scoped SSE, MVVM UI.

## Checklist

1. **Domain** — handwritten types, invariants, `*_ERROR` constants in
   `core/src/domain/<concept>.ts`. Failures go through `throwDomainError`.
   No I/O. No TypeBox.
2. **Use case** — `type CreateFoo = UseCase<"createFoo", Input, Output>` (camelCase
   name literal). Handwritten `Input`/`Output`. Member commands use
   `MemberUseCaseInput<{ … }>` unless the feature mints identity (no `userId`).
   Extend `UseCaseName` and `USE_CASE_NAMES`. Import from `@org/core/use-cases/*`,
   not the core root events module. Put query views next to the query contract.
3. **Validation** (when JSON crosses a boundary) — TypeBox schema + exported
   `InputValidator` in `@org/validation/input`; `additionalProperties: false`;
   wire with `withParsedExecute` at the composition root only. Reuse domain
   limit constants. Empty input still gets a validator.
4. **Event** (only if other clients must refresh) — add a variant to the
   closed union in `core/events.ts` that includes the scope id (`workspaceId`,
   and finer ids when useful: `projectId`, `issueId`). Publish an object literal
   after `run`. Subscribers listen on `workspaceId` and re-run queries; ViewModels
   may filter by event type and entity id. Skip the event when no other client
   needs to refresh.
5. **Driven port** — add or extend a port in `application` (often
   `ports/repositories/`). Persistence methods take `tx` first. Member commands
   use `RequestIdentity` + `requireActingUser(input, …)` — not a second wire
   actor parameter. Role-scoped products may use `requireHost()` / `requirePlayer()`
   instead; do not mix both models on the same wire.
6. **Interactor** — `createFoo(deps)` in `application`; `name` matches the type
   literal. One `uow.run` per `execute`; publish after `run` resolves.
7. **Tests** — mock ports; cover identity (`requireActingUser` or session),
   domain validation, commit-then-publish, domain errors.
8. **Adapters** — in-memory required; update SQLite (or other) adapter with the
   same port signatures.
9. **Delivery** — register in the composition root (`withParsedExecute` if
   needed). Extend the **flat** `ProductUseCases` object on `ProductApp` (one
   property per use case). Extend dispatch `switch` and `createProductClient` in
   `client.ts` (not `http-client.ts`). HTTP still takes `{ app: ProductApp }`.
   Wire names stay camelCase and match `UseCaseName`.
10. **UI** — ViewModel method → `client.<useCase>.execute({ userId, … })`.
    For live data, `client.events.subscribe(workspaceId, …)` then background
    `refresh()` on the active query (see `live-events` helpers). Do not import
    `application`, `infrastructure`, or `validation`.

## Mistakes to avoid

- TypeBox or `Static<>` in `core` domain or use-case modules
- Driven ports in the use-case package
- Parse logic inside interactors instead of composition-root wrappers
- Nesting use cases instead of composing ports in one `run`
- Kebab-case wire names that do not match the `UseCase` name literal
- `forMember` / nested facade on the wire when the app uses flat `MemberUseCaseInput`
- Trusting `input.userId` without matching `RequestIdentity`
- Putting read-time joins on the write DTO unless that is an explicit domain decision
- Framework metadata as domain fields
- Implicit live updates; publish after commit, subscribe by scope, re-query
- Fetch, URLs, or session header logic in `client.ts`
- Barrel `index.ts` re-export hubs
- Implementing a ring the user has not asked for yet
