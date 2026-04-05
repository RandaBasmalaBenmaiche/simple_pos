from pathlib import Path

from flask import Flask, abort, send_from_directory


BASE_DIR = Path(__file__).resolve().parent
WEB_DIR = BASE_DIR.parent.parent / "build" / "web"

app = Flask(__name__, static_folder=str(WEB_DIR), static_url_path="")


def _ensure_build_exists() -> None:
    if not WEB_DIR.exists():
        raise RuntimeError(
            "Flutter web build not found. Run `flutter build web --release` first."
        )


@app.before_request
def ensure_build() -> None:
    _ensure_build_exists()


@app.route("/")
def index():
    return send_from_directory(WEB_DIR, "index.html")


@app.route("/<path:path>")
def serve_flutter_app(path: str):
    target = WEB_DIR / path
    if target.exists() and target.is_file():
        return send_from_directory(WEB_DIR, path)

    if "." in path:
        abort(404)

    return send_from_directory(WEB_DIR, "index.html")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=False)
