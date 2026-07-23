# Bridge App — Live Link to SolidWorks

This is the "app" half of the project: a small local server that lets the
web simulator update SolidWorks directly, instead of you manually running a
macro each time. It runs on your machine (Windows, same PC as SolidWorks),
and the simulator talks to it over `localhost` while it's running.

## What it does

1. You run `bridge_server.py` — it starts a local server at
   `http://localhost:5175` and waits.
2. You open `index.html` in your browser. It automatically checks whether
   the bridge is running (green dot = connected).
3. Click **Send to SolidWorks (Live)** — the current spar geometry and
   safety status are sent straight to SolidWorks: dimensions update, the
   model rebuilds, and the spar body recolors by factor of safety.
4. If the bridge isn't running, the page falls back to the manual
   **Export .json** button + macro workflow from `SOLIDWORKS_SETUP.md` — the
   live link is a convenience layer on top of that, not a replacement.

## Setup

1. Install Python 3.10+ if you don't have it.
2. In this folder:
   ```
   pip install -r requirements.txt
   ```
3. Complete the SolidWorks-side setup from `SOLIDWORKS_SETUP.md` first
   (global variables `SparWidth` / `SparHeight` / `WallThickness`, and a
   solid body named `Spar`) — the bridge updates the same variables the
   macro does, just automatically.
4. Open your spar part in SolidWorks and leave it as the active document.
5. Run the bridge:
   ```
   python bridge_server.py
   ```
   You should see `Wing Load Sim <-> SolidWorks bridge starting...` in the
   console. Leave this window open while you work.
6. Open `wing_load_simulator.html` in your browser. The bridge status dot
   in the "CAD Link" panel should turn green within a few seconds.

## Testing without SolidWorks

The bridge runs in **mock mode** automatically if `pywin32` or SolidWorks
isn't available — it logs what it *would* do instead of erroring out. This
is how it was developed and tested (this project was built in a Linux
environment with no SolidWorks installed): every part of the server —
routing, payload validation, the browser↔server round trip — was verified
against the mock. Only the final COM calls into SolidWorks itself
(`solidworks_link.py`, `RealSolidWorksLink`) need verifying on your machine.

## Architecture

```
 browser (index.html)                bridge_server.py              SolidWorks
 ┌─────────────────────┐   HTTP      ┌──────────────────┐   COM     ┌───────────┐
 │ Send to SolidWorks   │ ───POST──▶ │ Flask /update     │ ────────▶│ Active     │
 │ (Live) button        │            │ validates payload │           │ document  │
 │ GET /health every 6s │ ◀────────  │ solidworks_link.py│           │            │
 └─────────────────────┘             └──────────────────┘           └───────────┘
```

- `bridge_server.py` — Flask app, request validation, routing.
- `solidworks_link.py` — the actual SolidWorks COM calls, isolated so they
  can be swapped for a mock during development/testing.

## Limitations

- Windows + SolidWorks + pywin32 only for the real (non-mock) path.
- The bridge must already be running before you click "Send to SolidWorks
  (Live)" — it doesn't launch SolidWorks or the server for you.
- Single active document only — it applies to whatever part is currently
  active in SolidWorks, not a specific file path.
- This is a development server (Flask's built-in one), fine for local,
  single-user use on your own machine — not meant to be exposed to a
  network or the internet.
