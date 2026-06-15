---
description: Deploy the current project to Cloudflare Pages with nt-deploy
---

Deploy the current folder to Cloudflare Pages using the nt-deploy MCP tools.

1. If a build is needed, build first.
2. Ask the user for the client/branch name (or confirm production).
3. Call the `nt_deploy` tool with `folder` and `client`.
4. Report the live URL and confirm a rollback snapshot was saved.
