# Templates

Replace placeholder names with the product’s vocabulary. **Issue tracker** shapes
are the reference; **order/customer** shapes illustrate the same mechanics with
a role-nested facade.

## Entity (handwritten core)

```ts
export type WorkspaceId = string;

export interface Workspace {
  id: WorkspaceId;
  name: string;
  slug: string;
}

export const WORKSPACE_NAME_MAX_LENGTH = 80;
export const WORKSPACE_SLUG_TAKEN_ERROR = "That slug is already in use.";
```

```ts
export function throwDomainError(message: string): never {
  const error = new Error(message);
  error.name = "DomainError";
  throw error;
}
```

## Use case (core) — flat member model (issue tracker)

camelCase `name` literals. Member commands wrap fields with `userId`.

```ts
export interface UseCase<Name extends string, Input, Output> {
  readonly name: Name;
  execute(input: Input): Promise<Output>;
}

export type MemberUseCaseInput<T> = { userId: UserId } & T;

export type CreateWorkspaceInput = {
  name: string;
  slug: string;
  displayName: string;
};
export type CreateWorkspaceOutput = { workspaceId: WorkspaceId; userId: UserId };
export type CreateWorkspace = UseCase<
  "createWorkspace",
  CreateWorkspaceInput,
  CreateWorkspaceOutput
>;

export type CreateProjectInput = MemberUseCaseInput<{
  workspaceId: WorkspaceId;
  name: string;
  key: string;
}>;
export type CreateProject = UseCase<"createProject", CreateProjectInput, void>;

type IssueTrackerUseCaseByName = {
  createWorkspace: CreateWorkspace;
  createProject: CreateProject;
  getProjectView: GetProjectView;
  // …
};

export type UseCaseName = keyof IssueTrackerUseCaseByName;

export const USE_CASE_NAMES = {
  createWorkspace: true,
  createProject: true,
  getProjectView: true,
} as const satisfies Record<UseCaseName, true>;

/** Flat facade — one property per use case. */
export type IssueTrackerUseCases = IssueTrackerUseCaseByName;
```

Query views (`ProjectView`, `IssueView`, …) live in `core/use-cases/views.ts`
and are rebuilt from persistence on every execute.

## Use case (core) — role-nested model (alternate products)

Use when host and player expose different command sets. Kebab-case names are
allowed if the product standardizes on them; stay consistent with `UseCaseName`.

```ts
export interface Actor {
  hostId: string | undefined;
  playerId: string | undefined;
}

export type PlaceOrder = UseCase<"place-order", PlaceOrderInput, void>;

export interface HostUseCases {
  placeOrder: PlaceOrder;
}

export interface ProductUseCases {
  createRoom: CreateRoom;
  forHost(hostId: HostId): HostUseCases;
}
```

## Identity port (application)

```ts
/** Bound per HTTP request from transport credentials. */
export interface RequestIdentity {
  requireCurrentUserId(): Promise<UserId>;
}
```

```ts
// In interactor:
const userId = await requireActingUser(
  input,
  deps.identity,
  deps.uow,
  deps.users,
);
```

## Driven port

```ts
export interface UnitOfWork {
  run<T>(work: (tx: TransactionContext) => Promise<T>): Promise<T>;
}

export interface ProjectRepository {
  insert(tx: TransactionContext, project: Project): Promise<void>;
  findById(tx: TransactionContext, id: ProjectId): Promise<Project | undefined>;
}
```

## Interactor (member command)

```ts
export function createCreateProject(deps: {
  identity: RequestIdentity;
  uow: UnitOfWork;
  projects: ProjectRepository;
  memberships: MembershipRepository;
  events: EventPublisher;
}): CreateProject {
  return {
    name: "createProject",
    async execute(input) {
      const userId = await requireActingUser(
        input,
        deps.identity,
        deps.uow,
        deps.users,
      );
      await deps.uow.run(async (tx) => {
        await requireMembership(tx, deps.memberships, input.workspaceId, userId);
        // … domain checks, deps.projects.insert(tx, …)
      });
      await deps.events.publish({
        type: "workspace-changed",
        workspaceId: input.workspaceId,
      });
    },
  };
}
```

Publish **after** `run` resolves. Omit `events` when no other client needs refresh.

## Event (core)

```ts
export interface ProjectChanged {
  type: "project-changed";
  workspaceId: WorkspaceId;
  projectId: ProjectId;
}

export type AppEvent = WorkspaceChanged | ProjectChanged | IssueChanged;

export interface EventSubscriber {
  subscribe(
    workspaceId: WorkspaceId,
    listener: (event: AppEvent) => void,
  ): Unsubscribe;
}
```

## Composition facade

```ts
export interface IssueTrackerApp extends IssueTrackerUseCases {
  events: EventPublisher & EventSubscriber;
}

export function createIssueTrackerApp(deps: {
  events: EventPublisher & EventSubscriber;
  identity?: RequestIdentity;
  uow?: UnitOfWork;
  // …optional port overrides + createSqlitePersistence()
}): IssueTrackerApp {
  const identity = deps.identity ?? createRequestIdentity();
  return {
    events: deps.events,
    createWorkspace: withParsedExecute(
      createWorkspaceInput,
      createCreateWorkspace({ uow, ids, … }),
    ),
    createProject: withParsedExecute(
      createProjectInput,
      createCreateProject({ identity, uow, …, events: deps.events }),
    ),
    // …flat list of every use case
  };
}
```

## Dispatch (no Actor parameter)

```ts
export function createUseCaseDispatcher(
  useCases: IssueTrackerUseCases,
): UseCaseDispatcher {
  const enqueue = createMutex();
  return {
    execute(name, input) {
      if (!isUseCaseName(name)) { /* NotFound */ }
      return enqueue(() => executeUseCase(useCases, name, input ?? {}));
    },
  };
}
```

## Client transport

```ts
export interface IssueTrackerClient extends IssueTrackerUseCases {
  events: EventSubscriber;
}

export interface UseCaseTransport {
  execute(name: UseCaseName, input: unknown): Promise<unknown>;
  events: EventSubscriber;
}

export function createIssueTrackerClient(
  transport: UseCaseTransport,
): IssueTrackerClient {
  return {
    createWorkspace: bindUseCase(transport, "createWorkspace"),
    createProject: bindUseCase(transport, "createProject"),
    // …
    events: transport.events,
  };
}
```

`http-client.ts`: `POST /api/use-cases` with `{ name, input }`; set session header
from `input.userId` when present; `GET /api/events/:workspaceId` SSE with reconnect.

## Delivery

```ts
const events = createInMemoryEventBus();
const app = createIssueTrackerApp({
  events,
  ...createSqlitePersistence({ path: process.env.DATABASE_PATH }),
});
createIssueTrackerHttpServer({ app, staticDir: process.env.STATIC_DIR });
```
