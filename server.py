"""
DeepShare Local DOCX Conversion Server
=======================================
Replacement for the paid API — converts Markdown to DOCX locally via Pandoc.

Endpoints:
  POST /convert-text              — convert Markdown → DOCX
  GET  /templates                 — list available templates
  GET  /subscriptions/my/quota    — return unlimited quota (stub)

Usage:
  python server.py                # starts on http://localhost:5050
"""

import os
import sys
import io
import tempfile
import subprocess
import uuid
from pathlib import Path

from flask import Flask, request, send_file, jsonify
from flask_cors import CORS

# ── Config ────────────────────────────────────────────────
PORT = 5050
BASE_DIR = Path(__file__).resolve().parent
FILTERS_DIR = BASE_DIR / "filters"
TEMPLATES_DIR = BASE_DIR / "templates"

app = Flask(__name__)
CORS(app)


# ── Helpers ───────────────────────────────────────────────

def _find_pandoc() -> str:
    """Find the pandoc executable, checking PATH and common install locations."""
    import shutil

    # 1. Try PATH first
    found = shutil.which("pandoc")
    if found:
        return found

    # 2. Windows: user-local install
    candidates = [
        os.path.expandvars(r"%LOCALAPPDATA%\Pandoc\pandoc.exe"),
        r"C:\Program Files\Pandoc\pandoc.exe",
        os.path.expandvars(r"%APPDATA%\Pandoc\pandoc.exe"),
    ]
    for c in candidates:
        if os.path.isfile(c or ""):
            return c

    raise RuntimeError(
        "Pandoc not found. Install from https://pandoc.org/installing.html"
    )


PANDOC = _find_pandoc()


def _run_pandoc(md_path: str, docx_path: str, options: dict) -> None:
    """Build and execute the pandoc command."""
    extra_filters = options.get("extra_lua_filters", []) or []
    hard_line_breaks = options.get("hard_line_breaks", False)
    remove_hr = options.get("remove_hr", False)
    template_name = options.get("template_name", "")
    compat_mode = options.get("compat_mode", True)

    # Base markdown format
    from_fmt = "markdown"
    if hard_line_breaks:
        from_fmt += "+hard_line_breaks"
    # Compatibility mode: accept raw HTML, tex math, etc.
    if compat_mode:
        from_fmt += "+raw_html+tex_math_dollars+tex_math_single_backslash"

    cmd = [
        PANDOC,
        md_path,
        "-o", docx_path,
        "-f", from_fmt,
        "--wrap=none",
    ]

    # Reference document (Word template)
    ref_doc = _resolve_template(template_name)
    if ref_doc:
        cmd += ["--reference-doc", str(ref_doc)]

    # Lua filters
    if remove_hr:
        _ensure_filter("remove-hr.lua", _LUA_REMOVE_HR)
        cmd += ["--lua-filter", str(FILTERS_DIR / "remove-hr.lua")]

    for name in extra_filters:
        if name == "disable-auto-numbering":
            fpath = FILTERS_DIR / "disable-auto-numbering.lua"
            if fpath.exists():
                cmd += ["--lua-filter", str(fpath)]

    print(f"[pandoc] {' '.join(cmd)}")
    subprocess.run(cmd, check=True, capture_output=True, text=True)


def _resolve_template(name: str) -> Path | None:
    """Find the best matching .docx template file."""
    # Allow the "templates" (universal) template through
    if not name:
        return None

    # Try exact match
    exact = TEMPLATES_DIR / f"{name}.docx"
    if exact.exists():
        return exact

    # Try fallback: reference.docx
    fallback = TEMPLATES_DIR / "reference.docx"
    if fallback.exists():
        print(f"[template] '{name}.docx' not found, using reference.docx")
        return fallback

    return None


def _ensure_filter(filename: str, content: str) -> None:
    """Write a Lua filter file if it doesn't exist."""
    fpath = FILTERS_DIR / filename
    if not fpath.exists():
        fpath.write_text(content, encoding="utf-8")
        print(f"[filter] created {filename}")


# ── Built-in Lua filters (written to disk on demand) ──────

_LUA_REMOVE_HR = """\
-- remove-hr.lua — strip horizontal rules from the output
function HorizontalRule()
  return {}
end
"""


# ── API Endpoints ─────────────────────────────────────────

@app.route("/convert-text", methods=["POST"])
def convert_text():
    """Convert Markdown text to DOCX and return the file."""
    data = request.get_json(force=True)
    content = data.get("content", "")
    filename = data.get("filename", "document")

    if not content:
        return jsonify({"detail": "content is required"}), 400

    options = {
        "hard_line_breaks": data.get("hard_line_breaks", False),
        "remove_hr": data.get("remove_hr", False),
        "compat_mode": data.get("compat_mode", True),
        "extra_lua_filters": data.get("extra_lua_filters", []),
        "template_name": data.get("template_name", ""),
    }

    # Sanitize filename
    safe_name = "".join(c for c in filename if c.isalnum() or c in "._- _")[:100]

    with tempfile.TemporaryDirectory() as tmpdir:
        md_path = os.path.join(tmpdir, f"{safe_name}.md")
        docx_path = os.path.join(tmpdir, f"{safe_name}.docx")

        # Write markdown to temp file
        Path(md_path).write_text(content, encoding="utf-8")

        try:
            _run_pandoc(md_path, docx_path, options)
        except subprocess.CalledProcessError as e:
            print(f"[pandoc] STDERR: {e.stderr}")
            return jsonify({"detail": f"Pandoc conversion failed: {e.stderr}"}), 500

        if not os.path.exists(docx_path):
            return jsonify({"detail": "Conversion produced no output"}), 500

        # Read into memory to avoid Windows file-locking issues with send_file
        with open(docx_path, "rb") as f:
            docx_bytes = f.read()

    return send_file(
        io.BytesIO(docx_bytes),
        mimetype="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        as_attachment=True,
        download_name=f"{safe_name}.docx",
    )


@app.route("/templates", methods=["GET"])
def list_templates():
    """Return available templates grouped by language."""
    templates_by_lang = {"zh": ["templates"], "en": ["templates"]}

    if TEMPLATES_DIR.exists():
        for f in TEMPLATES_DIR.glob("*.docx"):
            name = f.stem
            # Heuristic: Chinese names contain CJK characters
            if any("一" <= c <= "鿿" for c in name):
                if name not in templates_by_lang["zh"]:
                    templates_by_lang["zh"].append(name)
            else:
                if name not in templates_by_lang["en"]:
                    templates_by_lang["en"].append(name)

    return jsonify(templates_by_lang)


@app.route("/subscriptions/my/quota", methods=["GET"])
@app.route("/auth/quota", methods=["GET"])
def quota():
    """Return unlimited quota so the extension shows full access."""
    return jsonify({
        "email": "local@dev.null",
        "has_subscription": True,
        "subscription": {
            "plan_name": "Local Unlimited",
            "daily_quota": 999999,
            "used_today": 0,
            "expires_at": "2099-12-31T23:59:59Z",
            "status": "active",
            "auto_renew": True,
        },
        "addon_quota": {
            "total_quota": 999999,
            "used_quota": 0,
            "gift_quota": 0,
            "expires_at": "2099-12-31T23:59:59Z",
        },
    })


@app.route("/convert-text-to-url", methods=["POST"])
def convert_text_to_url():
    """Same conversion but returns a download URL (for md2docx skill CLI)."""
    # For local use, just delegate to /convert-text behavior
    # We return a localhost URL that points back to /download
    data = request.get_json(force=True)
    content = data.get("content", "")
    filename = data.get("filename", "document")

    if not content:
        return jsonify({"detail": "content is required"}), 400

    # Store in a simple in-memory cache
    doc_id = str(uuid.uuid4())[:8]
    options = {
        "hard_line_breaks": data.get("hard_line_breaks", False),
        "remove_hr": data.get("remove_hr", False),
        "compat_mode": data.get("compat_mode", True),
        "extra_lua_filters": data.get("extra_lua_filters", []),
        "template_name": data.get("template_name", ""),
    }

    safe_name = "".join(c for c in filename if c.isalnum() or c in "._- _")[:100]

    with tempfile.TemporaryDirectory() as tmpdir:
        md_path = os.path.join(tmpdir, f"{safe_name}.md")
        docx_path = os.path.join(tmpdir, f"{safe_name}.docx")
        Path(md_path).write_text(content, encoding="utf-8")

        try:
            _run_pandoc(md_path, docx_path, options)
        except subprocess.CalledProcessError as e:
            return jsonify({"detail": f"Pandoc conversion failed: {e.stderr}"}), 500

        # Read bytes before tmpdir cleanup (avoids Windows file-locking issue)
        with open(docx_path, "rb") as f:
            docx_bytes = f.read()

        # Save to a persistent download location from in-memory bytes
        out_dir = BASE_DIR / "downloads"
        out_dir.mkdir(exist_ok=True)
        final_path = out_dir / f"{doc_id}_{safe_name}.docx"
        final_path.write_bytes(docx_bytes)

    return jsonify({"url": f"http://localhost:{PORT}/download/{final_path.name}"})


@app.route("/download/<filename>", methods=["GET"])
def download_file(filename: str):
    """Serve a previously generated file."""
    fpath = BASE_DIR / "downloads" / filename
    if not fpath.exists():
        return jsonify({"detail": "file not found"}), 404
    return send_file(
        str(fpath),
        mimetype="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        as_attachment=True,
        download_name=filename.split("_", 1)[-1] if "_" in filename else filename,
    )


# ── Main ──────────────────────────────────────────────────

if __name__ == "__main__":
    print(f"""
╔══════════════════════════════════════════════╗
║   DeepShare Local DOCX Server                ║
║   http://localhost:{PORT}                      ║
║                                              ║
║   Endpoints:                                 ║
║     POST /convert-text    → Markdown → DOCX  ║
║     GET  /templates       → template list    ║
║     GET  /...quota        → unlimited quota  ║
╚══════════════════════════════════════════════╝
""")
    app.run(host="127.0.0.1", port=PORT, debug=True)
