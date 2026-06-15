---
description: Roll a client back to its previous deploy (nt-deploy Time Machine)
---

Restore a previous deploy using the nt-deploy MCP tools.

1. Ask which client/branch to roll back.
2. Call `nt_snapshots` to show the available snapshots.
3. Call `nt_rollback` with the client (and an optional `timestamp` for an exact version).
4. Report the restored live URL.
