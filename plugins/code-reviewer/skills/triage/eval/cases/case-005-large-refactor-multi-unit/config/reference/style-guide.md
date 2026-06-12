# Style Guide (Go — Layered Architecture)

## Layer Separation
- Handlers must not import repositories directly; all data access goes through services.
- Services must not use `gin.Context`; accept `context.Context` and plain request types.
- Repositories define an interface in the same package; implementations are injected.

## Error Handling
- Repositories return sentinel errors (`ErrNotFound`, `ErrConflict`) for business-level conditions.
- Services translate repository errors into domain errors where appropriate.
- Handlers map domain errors to HTTP status codes.

## Naming
- Service types: `<Domain>Service` (e.g., `UserService`).
- Repository interfaces: `<Domain>Repository` (e.g., `UserRepository`).
- Constructors: `New<Type>(deps...)` returning the concrete type.

## Singletons
- Avoid package-level `var Svc = &Service{}` without dependency injection.
  Prefer constructor injection for testability.
