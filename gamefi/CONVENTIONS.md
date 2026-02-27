# GameFi Conventions

## Naming

- Address-type user identity uses `player` consistently.
- Primary identifiers use `*Id` suffix.
- Time fields use `*At` suffix in unix seconds.

## Interface Shape

- Read interfaces prefer `getX(...)` / `listX(...)`.
- List results should return stable ID arrays when possible.
- Module-level structs stay in `*Types.sol` and events in `*Events.sol`.

## Event Shape

- Actor address should be indexed when possible.
- Domain identifiers (`questId`, `seasonId`, `battleId`) should be indexed in core events.
- Event fields should align with corresponding struct field names.
