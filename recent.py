#!/usr/bin/env python3
"""Recent Claude Code desktop sessions. Run it, open http://127.0.0.1:7799

--demo serves made-up sessions from demo.json on port 7798 instead.
"""
import glob, json, os, re, subprocess, sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STORE = os.path.expanduser("~/Library/Application Support/Claude/claude-code-sessions")
HOME = os.path.expanduser("~")
DEMO = "--demo" in sys.argv
PORT = 7798 if DEMO else 7799


def demo_sessions():
    with open(os.path.join(os.path.dirname(__file__), "demo.json")) as f:
        rows = json.load(f)
    now = time.time() * 1000
    return [{"cwd": f"~/code/{r['project']}", "archived": False, "branch": None, "pr": None, "prState": None,
             "prUrl": None, "action": None, "detail": None, "parent": None, "kind": None,
             **r, "at": now - r.pop("ago") * 60000} for r in rows]


def sessions():
    if DEMO:
        return demo_sessions()
    out = []
    for path in glob.glob(f"{STORE}/*/*/local_*.json"):
        try:
            with open(path) as f:
                s = json.load(f)
        except (OSError, ValueError):
            continue  # the app rewrites these files, a half-written one shows up next poll
        summary = s.get("postTurnSummary") or {}
        cwd = s.get("originCwd") or s.get("cwd") or ""
        spawned = (s.get("spawnedFrom") or {}).get("sessionId")
        out.append({
            "id": s.get("sessionId"),
            "title": s.get("title") or "(untitled)",
            "cwd": cwd.replace(HOME, "~", 1),
            "project": os.path.basename(cwd) or "?",
            "at": s.get("lastActivityAt") or s.get("createdAt") or 0,
            "archived": bool(s.get("isArchived")),
            "turns": s.get("completedTurns") or 0,
            "status": summary.get("status_category"),
            "detail": summary.get("status_detail"),
            "action": summary.get("needs_action"),
            "branch": s.get("branch"),
            "pr": s.get("prNumber"),
            "prState": s.get("prState"),
            "prUrl": s.get("prUrl"),
            "parent": spawned or s.get("forkedFromSessionId"),
            "kind": "spawned" if spawned else "fork" if s.get("forkedFromSessionId") else None,
        })
    return sorted(out, key=lambda s: -s["at"])


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/data":
            body, ctype = json.dumps(sessions()).encode(), "application/json"
        elif self.path == "/":
            with open(os.path.join(os.path.dirname(__file__), "recent.html"), "rb") as f:
                body, ctype = f.read(), "text/html; charset=utf-8"
        else:
            return self.send_error(404)
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        # Only this page may switch sessions. Other sites can't forge Origin, and the id must look like the app's.
        sid = self.path.removeprefix("/open/")
        if self.headers.get("Origin") not in (f"http://127.0.0.1:{PORT}", f"http://localhost:{PORT}") \
                or not re.fullmatch(r"local_[0-9a-f-]{36}", sid):
            return self.send_error(403)
        if not DEMO:  # demo sessions don't exist in the app
            subprocess.run(["open", f"claude://claude.ai/epitaxy/{sid}"])  # the app handles this link, the Browser pane doesn't
        self.send_response(204)
        self.end_headers()

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    print(f"http://127.0.0.1:{PORT}")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
