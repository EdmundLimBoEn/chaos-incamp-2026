# Backend
Convex calendar CRUD, host profiles and explicitly published event listings. Private events are never returned by public discovery.
`discovery:search` supports text, tag, host and date filters with pagination. Continue while `isDone` is false, including empty tag-filtered pages.
Run `bun install`, configure a Convex deployment, then `bun run dev`.
Development backend: https://majestic-vulture-890.convex.cloud. iOS public discovery uses this URL. Username/password sign-in is configured through Convex Auth; usernames are case-insensitive, 3–30 letters/numbers/underscores, passwords at least 8 characters. No password recovery is configured. Private iOS sync is not connected. MCP execution remains unimplemented; future tools must check revocable grants and user approval.
Written by gpt-6.1-sol in Codex on behalf of Edmund
