"""
bridge_server.py

Local bridge between the Wing Load Sim web page and SolidWorks.

Run this on the same Windows machine as SolidWorks:

    pip install -r requirements.txt
    python bridge_server.py

Then open wing_load_simulator.html in your browser (with SolidWorks + the
spar part open) and click "Send to SolidWorks (Live)". The button POSTs the
current geometry/status to http://localhost:5175/update, which this server
applies to the model via solidworks_link.py.

If SolidWorks/pywin32 isn't available, this still runs in mock mode --
useful for testing the connection itself before you're on the SolidWorks PC.
"""

import logging
from flask import Flask, request, jsonify
from flask_cors import CORS

from solidworks_link import get_link, SolidWorksUnavailable

logging.basicConfig(level=logging.INFO, format="%(asctime)s  %(levelname)s  %(message)s")
log = logging.getLogger("bridge_server")

app = Flask(__name__)
CORS(app)  # allow the browser page (file:// or any localhost port) to reach this server

REQUIRED_TOP_LEVEL = ["schema", "geometry_mm", "status", "statusColorRGB01"]
REQUIRED_GEOMETRY = ["sparWidth", "sparHeight", "wallThickness"]
EXPECTED_SCHEMA = "wing-load-sim/solidworks-export/v1"


def validate_payload(payload):
    if not isinstance(payload, dict):
        return "Payload must be a JSON object."
    for key in REQUIRED_TOP_LEVEL:
        if key not in payload:
            return f"Missing required field: {key}"
    if payload.get("schema") != EXPECTED_SCHEMA:
        return f"Unexpected schema '{payload.get('schema')}', expected '{EXPECTED_SCHEMA}'"
    geom = payload["geometry_mm"]
    for key in REQUIRED_GEOMETRY:
        if key not in geom:
            return f"Missing geometry field: {key}"
    rgb = payload["statusColorRGB01"]
    if not (isinstance(rgb, list) and len(rgb) == 3):
        return "statusColorRGB01 must be a 3-element array."
    return None


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"ok": True, "service": "wing-load-sim-bridge"})


@app.route("/update", methods=["POST"])
def update():
    payload = request.get_json(silent=True)
    error = validate_payload(payload)
    if error:
        log.warning("Rejected payload: %s", error)
        return jsonify({"ok": False, "error": error}), 400

    log.info(
        "Update received: %sx%sx%s mm, status=%s",
        payload["geometry_mm"]["sparWidth"],
        payload["geometry_mm"]["sparHeight"],
        payload["geometry_mm"]["wallThickness"],
        payload["status"],
    )

    try:
        link = get_link()
        result = link.apply(payload)
        return jsonify({"ok": True, "result": result})
    except SolidWorksUnavailable as e:
        log.error("SolidWorks unavailable: %s", e)
        return jsonify({"ok": False, "error": str(e)}), 503
    except Exception as e:
        log.exception("Unexpected error applying update")
        return jsonify({"ok": False, "error": f"Unexpected error: {e}"}), 500


if __name__ == "__main__":
    log.info("Wing Load Sim <-> SolidWorks bridge starting on http://localhost:5175")
    log.info("pywin32 available: %s", __import__("solidworks_link").HAVE_PYWIN32)
    app.run(host="127.0.0.1", port=5175, debug=False)
