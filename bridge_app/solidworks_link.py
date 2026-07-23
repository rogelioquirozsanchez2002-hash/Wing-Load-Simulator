"""
solidworks_link.py

Wraps the SolidWorks COM automation calls behind a small interface so the
rest of the bridge app (Flask server, routing, JSON handling) can be built
and tested without SolidWorks installed.

- On Windows with SolidWorks + pywin32 installed: uses the real COM API.
- Anywhere else (or if pywin32 import fails): falls back to a Mock link that
  logs what it *would* do. This lets you run/test the bridge server itself
  on any machine, and only needs the real path once you're on your
  SolidWorks PC.

Real-path SolidWorks API calls used here follow the same pattern as the
companion VBA macro (WingLoadSim_SolidWorksLink.swp.bas) — Equation Manager
for global variables, Body2.MaterialPropertyValues for body color. As noted
in SOLIDWORKS_SETUP.md, this hasn't been run against a live SolidWorks
instance in development; validate on your machine and adjust if your
SolidWorks version's exact API surface differs.
"""

import logging

log = logging.getLogger("solidworks_link")

try:
    import win32com.client  # pywin32 -- only importable on Windows
    HAVE_PYWIN32 = True
except ImportError:
    HAVE_PYWIN32 = False


class SolidWorksUnavailable(Exception):
    """Raised when a real SolidWorks connection is required but not available."""


class RealSolidWorksLink:
    """Live COM link to a running SolidWorks instance. Windows + pywin32 + SolidWorks only."""

    SPAR_BODY_NAME = "Spar"

    def __init__(self):
        if not HAVE_PYWIN32:
            raise SolidWorksUnavailable("pywin32 not available -- run this on Windows with pywin32 installed.")
        try:
            self.sw_app = win32com.client.GetActiveObject("SldWorks.Application")
        except Exception as e:
            raise SolidWorksUnavailable(
                "Could not attach to a running SolidWorks instance. "
                "Make sure SolidWorks is open with the spar part active."
            ) from e

    def apply(self, payload: dict) -> dict:
        model = self.sw_app.ActiveDoc
        if model is None:
            raise SolidWorksUnavailable("No active document in SolidWorks. Open the spar part first.")

        geom = payload["geometry_mm"]
        eqn_mgr = model.Extension.GetEquationMgr()
        self._set_global_variable(eqn_mgr, "SparWidth", geom["sparWidth"])
        self._set_global_variable(eqn_mgr, "SparHeight", geom["sparHeight"])
        self._set_global_variable(eqn_mgr, "WallThickness", geom["wallThickness"])

        model.EditRebuild3()

        r, g, b = payload["statusColorRGB01"]
        found = self._color_body(model, self.SPAR_BODY_NAME, r, g, b)

        return {
            "applied": True,
            "bodyColored": found,
            "geometry_mm": geom,
            "status": payload.get("status"),
        }

    def _set_global_variable(self, eqn_mgr, name, value_mm):
        count = eqn_mgr.GetCount()
        target = f'"{name}"'
        for i in range(count):
            text = eqn_mgr.Equation(i)
            if target in text:
                eqn_mgr.Equation[i] = f'{target} = {value_mm}mm'
                return
        eqn_mgr.Add2(-1, f'{target} = {value_mm}mm', False)

    def _color_body(self, model, body_name, r, g, b):
        bodies = model.GetBodies2(0, True)
        if not bodies:
            return False
        for body in bodies:
            if body.Name == body_name:
                body.MaterialPropertyValues = (0.1, r, g, b, 0.4, 0.4, 0.4, 0.0, 0.0)
                return True
        return False


class MockSolidWorksLink:
    """Stand-in used when SolidWorks/pywin32 isn't available -- logs the intended actions."""

    def apply(self, payload: dict) -> dict:
        geom = payload["geometry_mm"]
        log.info(
            "[MOCK] Would set globals SparWidth=%s SparHeight=%s WallThickness=%s, "
            "rebuild, and color body 'Spar' to RGB=%s (status=%s)",
            geom["sparWidth"], geom["sparHeight"], geom["wallThickness"],
            payload.get("statusColorRGB01"), payload.get("status"),
        )
        return {
            "applied": True,
            "mock": True,
            "bodyColored": True,
            "geometry_mm": geom,
            "status": payload.get("status"),
        }


def get_link():
    """Returns a real link if SolidWorks/pywin32 is available, otherwise a mock."""
    if not HAVE_PYWIN32:
        return MockSolidWorksLink()
    try:
        return RealSolidWorksLink()
    except SolidWorksUnavailable as e:
        log.warning("Falling back to mock link: %s", e)
        return MockSolidWorksLink()
