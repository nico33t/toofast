#!/usr/bin/env python3
"""nt-deploy MCP server — exposes nt-deploy to Claude Code (and any MCP client).

stdio transport, JSON-RPC 2.0, newline-delimited. No third-party deps.
Every tool shells out to nt-deploy.sh with a strict, no-shell argv and a
conservative argument allowlist (same security posture as the GUI)."""
import json, os, re, shutil, subprocess, sys

SCRIPT = os.environ.get("NT_SCRIPT") or shutil.which("nt-deploy.sh") \
    or os.path.expanduser("~/.nt-tools/nt-deploy.sh")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
SAFE = re.compile(r"^[A-Za-z0-9._:/?=&%@ -]+$")
PROTOCOL = "2024-11-05"

# tool name -> (nt-deploy subcommand, [positional arg keys], extra flags)
TOOLS = {
    "nt_deploy":    ("push",      ["folder", "client"], ["-y"]),
    "nt_rollback":  ("rollback",  ["client", "timestamp"], []),
    "nt_snapshots": ("snapshots", ["client"], []),
    "nt_audit":     ("audit",     ["target", "strategy"], []),
    "nt_check":     ("check",     ["target"], []),
    "nt_clients":   ("clients",   [], []),
    "nt_projects":  ("projects",  [], []),
    "nt_list":      ("list",      [], []),
    "nt_create":    ("create",    ["client"], []),
}

SCHEMAS = {
    "nt_deploy":    {"folder": "Folder to deploy (e.g. ./dist or site)",
                     "client": "Client/branch name (omit for production)"},
    "nt_rollback":  {"client": "Client/branch to roll back",
                     "timestamp": "Optional exact snapshot timestamp"},
    "nt_snapshots": {"client": "Client/branch (default: main)"},
    "nt_audit":     {"target": "URL or client name", "strategy": "mobile or desktop"},
    "nt_check":     {"target": "URL or client name"},
    "nt_clients":   {},
    "nt_projects":  {},
    "nt_list":      {},
    "nt_create":    {"client": "Client name for the new premium scaffold"},
}
DESC = {
    "nt_deploy":    "Deploy a folder to Cloudflare Pages (a client branch or production).",
    "nt_rollback":  "Roll a client back to its previous deploy (local snapshot).",
    "nt_snapshots": "List local deploy snapshots for a client.",
    "nt_audit":     "Run a real PageSpeed audit (Google Lighthouse engine) and return scores.",
    "nt_check":     "HTTP health-check of a URL or client: status, time, size.",
    "nt_clients":   "List active clients/branches in the project.",
    "nt_projects":  "List Cloudflare Pages projects.",
    "nt_list":      "List recent deployments of the project.",
    "nt_create":    "Scaffold a premium, PageSpeed-optimized starter site for a client.",
}

def tool_defs():
    out = []
    for name, props in SCHEMAS.items():
        req = ["client"] if name in ("nt_rollback",) else []
        out.append({
            "name": name, "description": DESC[name],
            "inputSchema": {"type": "object",
                "properties": {k: {"type": "string", "description": v} for k, v in props.items()},
                "required": req},
        })
    return out

def call_tool(name, args, project):
    if name not in TOOLS:
        return f"unknown tool: {name}"
    sub, keys, flags = TOOLS[name]
    argv = [SCRIPT]
    if project and SAFE.match(str(project)):
        argv += ["-p", str(project)]
    argv.append(sub)
    for k in keys:
        v = args.get(k)
        if v and SAFE.match(str(v)):
            argv.append(str(v))
    argv += flags
    try:
        r = subprocess.run(argv, capture_output=True, text=True, timeout=180)
        return ANSI.sub("", (r.stdout or "") + (r.stderr or "")).strip() or "(no output)"
    except subprocess.TimeoutExpired:
        return "timeout"
    except Exception as e:
        return f"error: {e}"

def handle(req):
    m = req.get("method"); rid = req.get("id"); p = req.get("params") or {}
    if m == "initialize":
        return {"jsonrpc": "2.0", "id": rid, "result": {
            "protocolVersion": PROTOCOL,
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "nt-deploy", "version": "2.0.0"}}}
    if m == "tools/list":
        return {"jsonrpc": "2.0", "id": rid, "result": {"tools": tool_defs()}}
    if m == "tools/call":
        args = p.get("arguments") or {}
        text = call_tool(p.get("name", ""), args, args.get("project", os.environ.get("NT_PROJECT", "")))
        return {"jsonrpc": "2.0", "id": rid, "result": {"content": [{"type": "text", "text": text}]}}
    if m and m.startswith("notifications/"):
        return None  # notifications get no response
    if rid is not None:
        return {"jsonrpc": "2.0", "id": rid, "error": {"code": -32601, "message": f"method not found: {m}"}}
    return None

def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except Exception:
            continue
        resp = handle(req)
        if resp is not None:
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()

if __name__ == "__main__":
    main()
