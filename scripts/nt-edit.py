#!/usr/bin/env python3
"""nt-deploy edit — featherweight live dev server with a built-in text editor.

stdlib only, binds 127.0.0.1. Serves a static folder, auto-reloads the browser on
save (SSE), and injects a tiny editor panel: pick a file, edit, save to disk. For
multilingual sites it lists the language JSON files so you edit the one you're viewing.

Security: per-session token on write/read APIs, Host-header allowlist, writes confined
to the served folder (no path traversal), text files only, size-capped.

Usage:  nt-edit <dir> [port]   (launched by nt-deploy.sh)."""
import json, mimetypes, os, secrets, sys, threading, time, urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SRV = None  # set in __main__, used by the /__nt/stop endpoint

ROOT = os.path.realpath(sys.argv[1]) if len(sys.argv) > 1 else os.getcwd()
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8080
TOKEN = secrets.token_urlsafe(18)
ALLOWED_HOSTS = {f"127.0.0.1:{PORT}", f"localhost:{PORT}", f"nt.local:{PORT}"}
TEXT_EXT = {".html", ".htm", ".css", ".js", ".mjs", ".json", ".webmanifest",
            ".md", ".txt", ".svg", ".xml"}
SKIP_DIR = {"node_modules", ".git", "dist", ".wrangler", ".turbo", "__pycache__", ".next"}
MAX = 2 * 1024 * 1024

def inside(path):
    rp = os.path.realpath(path)
    return rp == ROOT or rp.startswith(ROOT + os.sep)

def list_files():
    out = []
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIR and not d.startswith(".")]
        for f in files:
            if os.path.splitext(f)[1].lower() in TEXT_EXT:
                rel = os.path.relpath(os.path.join(base, f), ROOT)
                out.append(rel)
    out.sort()
    return out

def find_text(q):
    q = " ".join((q or "").split())[:80]
    for needle in (q.lower(), q.lower()[:35]):
        if len(needle) < 3:
            continue
        for rel in list_files():
            try:
                with open(os.path.join(ROOT, rel), encoding="utf-8", errors="replace") as fh:
                    for i, line in enumerate(fh, 1):
                        if needle in " ".join(line.split()).lower():
                            return {"path": rel, "line": i}
            except OSError:
                continue
    return None

def latest_mtime():
    m = 0.0
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIR and not d.startswith(".")]
        for f in files:
            try:
                m = max(m, os.path.getmtime(os.path.join(base, f)))
            except OSError:
                pass
    return m

PANEL = """
<style id="nt-ed-style">
#nt-fab{position:fixed;right:16px;bottom:16px;z-index:2147483646;display:flex;gap:6px;align-items:center;
background:#18181b;color:#fff;border-radius:12px;padding:6px;box-shadow:0 8px 24px rgba(0,0,0,.32);
font:600 13px system-ui;touch-action:none;transition:right .22s ease,top .22s ease}
#nt-fab.drag{transition:none;opacity:.93}
#nt-fab .grip{cursor:grab;color:#7a7a85;padding:0 4px;user-select:none}#nt-fab.drag .grip{cursor:grabbing}
#nt-fab button{border:0;border-radius:8px;padding:8px 11px;font:inherit;cursor:pointer;background:#2a2a31;color:#fff}
#nt-fab button:hover{background:#3a3a44}
#nt-fab button.on{background:#6d4aff;color:#fff}
#nt-fab .stop{background:#3a1620;color:#ff8a9b}#nt-fab .stop:hover{background:#52202c}
#nt-ed{position:fixed;inset:auto 0 0 0;height:46vh;z-index:2147483647;background:#0b1020;color:#e6f0ff;
display:none;grid-template-columns:230px 1fr;font:13px system-ui;border-top:2px solid #6d4aff}
#nt-ed.open{display:grid}
#nt-ed .side{border-right:1px solid #243049;overflow:auto;padding:8px}
#nt-ed .side b{display:block;color:#8aa;font:600 11px system-ui;letter-spacing:.1em;padding:6px 8px}
#nt-ed .f{padding:6px 8px;border-radius:6px;cursor:pointer;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#nt-ed .f:hover,#nt-ed .f.on{background:#1b2740}
#nt-ed .main{display:flex;flex-direction:column}
#nt-ed .bar{display:flex;gap:8px;align-items:center;padding:8px 10px;border-bottom:1px solid #243049}
#nt-ed .bar .p{flex:1;color:#9fb0d0;font:12px ui-monospace,monospace;overflow:hidden;text-overflow:ellipsis}
#nt-ed textarea{flex:1;width:100%;border:0;resize:none;padding:12px;background:#070d1c;color:#dce8ff;
font:13px/1.5 ui-monospace,monospace;tab-size:2}
#nt-ed button{border:0;border-radius:7px;padding:7px 12px;font:600 12px system-ui;cursor:pointer}
#nt-ed .save{background:#6d4aff;color:#fff}#nt-ed .x{background:#243049;color:#cdd}
#nt-ed .lang{background:#11203a;color:#7fdcff}
</style>
<div id="nt-fab"><span class="grip" title="drag me">⠿</span><button id="nt-ed-pick" title="Click an element on the page to jump to its source line">🎯</button><button id="nt-ed-open">✎ Edit</button><button class="stop" id="nt-ed-stop" title="Stop live server">⏻ Stop</button></div>
<div id="nt-ed"><div class="side"><b>FILES</b><div id="nt-ed-list"></div></div>
<div class="main"><div class="bar"><span class="p" id="nt-ed-path">no file</span>
<button class="lang" id="nt-ed-lang" style="display:none"></button>
<button class="save" id="nt-ed-save">Save (⌘S)</button><button class="x" id="nt-ed-x">✕</button></div>
<textarea id="nt-ed-ta" spellcheck="false" placeholder="Pick a file to edit…"></textarea></div></div>
<script>
(function(){var T="__NT_TOKEN__",cur=null,$=function(i){return document.getElementById(i)};
var lang=new URLSearchParams(location.search).get("lang")||document.documentElement.lang||"";
new EventSource("/__nt/reload?t="+T).onmessage=function(ev){
 if(ev.data=="css"){[].forEach.call(document.querySelectorAll('link[rel="stylesheet"]'),function(l){
  var u=(l.href||"").split("?")[0];if(u)l.href=u+"?v="+Date.now();});}
 else location.reload();};
var fab=$("nt-fab");
$("nt-ed-open").onclick=function(){$("nt-ed").classList.toggle("open");if($("nt-ed").classList.contains("open"))load()};
$("nt-ed-x").onclick=function(){$("nt-ed").classList.remove("open")};
$("nt-ed-stop").onclick=function(){fetch("/__nt/stop",{method:"POST",headers:{"X-NT-Token":T}}).finally(function(){
 document.documentElement.innerHTML='<body style="margin:0;font:600 16px system-ui;display:grid;place-items:center;height:100vh;background:#0b1020;color:#7a8aa5">live server stopped — you can close this tab</body>';});};
// draggable; snaps back to the right edge on release
(function(){var dx=0,dy=0,drag=false;
 fab.addEventListener("pointerdown",function(e){if(e.target.tagName=="BUTTON")return;drag=true;fab.classList.add("drag");
  var r=fab.getBoundingClientRect();dx=e.clientX-r.left;dy=e.clientY-r.top;try{fab.setPointerCapture(e.pointerId)}catch(x){}});
 fab.addEventListener("pointermove",function(e){if(!drag)return;
  fab.style.left=(e.clientX-dx)+"px";fab.style.top=(e.clientY-dy)+"px";fab.style.right="auto";fab.style.bottom="auto";});
 fab.addEventListener("pointerup",function(e){if(!drag)return;drag=false;fab.classList.remove("drag");
  var y=parseFloat(fab.style.top)||0;y=Math.max(8,Math.min(window.innerHeight-fab.offsetHeight-8,y));
  fab.style.left="auto";fab.style.bottom="auto";fab.style.right="16px";fab.style.top=y+"px";});  // re-dock right
})();
function load(){fetch("/__nt/files?t="+T).then(function(r){return r.json()}).then(function(fs){
 var L=$("nt-ed-list");L.innerHTML="";var pick=null;
 fs.forEach(function(f){var d=document.createElement("div");d.className="f";d.textContent=f;
  d.onclick=function(){open_(f,d)};L.appendChild(d);
  if(lang&&/\\.json$/.test(f)&&f.toLowerCase().indexOf(lang.toLowerCase())>=0)pick=[f,d];});
 if(pick){open_(pick[0],pick[1]);$("nt-ed-lang").style.display="";$("nt-ed-lang").textContent="lang: "+lang}});}
function open_(f,el){[].forEach.call(document.querySelectorAll("#nt-ed .f"),function(x){x.classList.remove("on")});
 if(el)el.classList.add("on");openAt(f,1);}
function openAt(f,line){cur=f;$("nt-ed-path").textContent=f+(line>1?":"+line:"");
 fetch("/__nt/file?t="+T+"&path="+encodeURIComponent(f)).then(function(r){return r.text()}).then(function(txt){
  var ta=$("nt-ed-ta");ta.value=txt;
  if(line>1){var ls=txt.split("\\n"),s=0,i;for(i=0;i<line-1&&i<ls.length;i++)s+=ls[i].length+1;
   var e=s+(ls[line-1]?ls[line-1].length:0);ta.focus();ta.setSelectionRange(s,e);
   var lh=parseFloat(getComputedStyle(ta).lineHeight)||18;ta.scrollTop=Math.max(0,(line-3)*lh);}
 });}
function save(){if(!cur)return;fetch("/__nt/save",{method:"POST",headers:{"Content-Type":"application/json","X-NT-Token":T},
 body:JSON.stringify({path:cur,content:$("nt-ed-ta").value})}).then(function(r){if(!r.ok)alert("save failed")});}
$("nt-ed-save").onclick=save;
document.addEventListener("keydown",function(e){if((e.metaKey||e.ctrlKey)&&e.key=="s"&&$("nt-ed").classList.contains("open")){e.preventDefault();save()}});
// auto-save (debounced) → live reload makes edits feel real-time
var asT;$("nt-ed-ta").addEventListener("input",function(){clearTimeout(asT);asT=setTimeout(save,700)});
// click-to-source ("vibe coding"): pick an element on the page, jump to its file + line
var inspect=false;
$("nt-ed-pick").onclick=function(){inspect=!inspect;this.classList.toggle("on",inspect);document.body.style.cursor=inspect?"crosshair":""};
document.addEventListener("click",function(e){if(!inspect)return;if(e.target.closest("#nt-ed")||e.target.closest("#nt-fab"))return;
 e.preventDefault();e.stopPropagation();var t=(e.target.textContent||"").trim().replace(/\\s+/g," ").slice(0,80);if(!t)return;
 fetch("/__nt/find?t="+T+"&q="+encodeURIComponent(t)).then(function(r){return r.json()}).then(function(m){
  if(!m||!m.path)return;$("nt-ed").classList.add("open");openAt(m.path,m.line||1);});},true);
})();
</script>
"""

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _host_ok(self): return self.headers.get("Host", "") in ALLOWED_HOSTS
    def _tok(self, q=None):
        return self.headers.get("X-NT-Token") == TOKEN or (q and q.get("t", [""])[0] == TOKEN)
    def _send(self, code, body, ctype="text/plain; charset=utf-8", extra=None):
        b = body.encode() if isinstance(body, str) else body
        self.send_response(code); self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(b)))
        for k, v in (extra or {}).items(): self.send_header(k, v)
        self.end_headers(); self.wfile.write(b)
    def _resolve(self, rel):
        p = os.path.realpath(os.path.join(ROOT, rel.lstrip("/")))
        return p if inside(p) else None

    def do_GET(self):
        if not self._host_ok(): return self._send(403, "forbidden host")
        u = urllib.parse.urlparse(self.path); q = urllib.parse.parse_qs(u.query); path = u.path
        if path == "/__nt/files":
            if not self._tok(q): return self._send(403, "forbidden")
            return self._send(200, json.dumps(list_files()), "application/json")
        if path == "/__nt/find":
            if not self._tok(q): return self._send(403, "forbidden")
            return self._send(200, json.dumps(find_text(q.get("q", [""])[0]) or {}), "application/json")
        if path == "/__nt/file":
            if not self._tok(q): return self._send(403, "forbidden")
            f = self._resolve(q.get("path", [""])[0])
            if not f or not os.path.isfile(f): return self._send(404, "not found")
            try: return self._send(200, open(f, "rb").read())
            except OSError: return self._send(500, "read error")
        if path == "/__nt/reload":
            if not self._tok(q): return self._send(403, "forbidden")
            self.send_response(200); self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache"); self.end_headers()
            def snap():
                d = {}
                for base, dirs, files in os.walk(ROOT):
                    dirs[:] = [x for x in dirs if x not in SKIP_DIR and not x.startswith(".")]
                    for f in files:
                        try: d[os.path.join(base, f)] = os.path.getmtime(os.path.join(base, f))
                        except OSError: pass
                return d
            prev = snap()
            try:
                while True:
                    time.sleep(0.6); cur = snap()
                    changed = [p for p, mt in cur.items() if prev.get(p) != mt] + [p for p in prev if p not in cur]
                    if changed:
                        exts = {os.path.splitext(p)[1].lower() for p in changed}
                        prev = cur
                        msg = "css" if exts and exts <= {".css"} else "reload"  # CSS-only → hot swap, no full reload
                        self.wfile.write(("data: " + msg + "\n\n").encode()); self.wfile.flush()
                    else:
                        self.wfile.write(b": ping\n\n"); self.wfile.flush()
            except Exception:
                return
        # static
        rel = urllib.parse.unquote(path)
        if rel.endswith("/"): rel += "index.html"
        f = self._resolve(rel)
        if f and os.path.isdir(f): f = os.path.join(f, "index.html")
        if not f or not os.path.isfile(f): return self._send(404, "404 — not found")
        ctype = mimetypes.guess_type(f)[0] or "application/octet-stream"
        try: data = open(f, "rb").read()
        except OSError: return self._send(500, "read error")
        if ctype.startswith("text/html"):
            html = data.decode("utf-8", "replace")
            inj = PANEL.replace("__NT_TOKEN__", TOKEN)
            html = html.replace("</body>", inj + "</body>", 1) if "</body>" in html else html + inj
            return self._send(200, html, "text/html; charset=utf-8")
        self._send(200, data, ctype)

    def do_POST(self):
        if not self._host_ok(): return self._send(403, "forbidden host")
        if not self._tok(): return self._send(403, "forbidden")
        if self.path == "/__nt/stop":
            self._send(200, "stopping")
            if SRV: threading.Thread(target=SRV.shutdown, daemon=True).start()
            return
        if self.path != "/__nt/save": return self._send(404, "not found")
        n = int(self.headers.get("Content-Length", 0) or 0)
        if n > MAX: return self._send(413, "too large")
        try: d = json.loads(self.rfile.read(n) or b"{}")
        except Exception: return self._send(400, "bad json")
        f = self._resolve(str(d.get("path", "")))
        if not f or os.path.splitext(f)[1].lower() not in TEXT_EXT:
            return self._send(403, "path not allowed")
        try:
            with open(f, "w", encoding="utf-8") as fh: fh.write(str(d.get("content", "")))
            return self._send(200, "saved")
        except OSError as e:
            return self._send(500, str(e))

if __name__ == "__main__":
    print(f"nt-deploy edit · http://localhost:{PORT} · {ROOT}")
    print("  live reload on save · drag the bottom-right widget · ✎ Edit / ⏻ Stop")
    SRV = ThreadingHTTPServer(("127.0.0.1", PORT), H)
    try:
        SRV.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped.")
