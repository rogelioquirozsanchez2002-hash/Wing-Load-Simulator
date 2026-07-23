# Wing Load Sim → SolidWorks Link — Setup Guide

This connects the web simulator to a real SolidWorks part: the simulator exports
a small `.json` with the optimized spar geometry and its safety status, and a
VBA macro reads it, resizes your model, and colors it green / amber / red.

There's no live/automatic connection between the browser and SolidWorks (a
web page can't reach into a desktop app for security reasons) — the flow is:
**web tool → download .json → run macro in SolidWorks.** Takes a few seconds
each time, and is the same pattern used for real analysis-to-CAD handoffs.

## 1. Build (or adapt) the spar part

If you don't have a hollow-box spar part yet:

1. New Part → sketch a rectangle for the outer profile of the spar cross-section.
2. Offset the same rectangle inward to create the hollow wall (or use the
   Shell feature after extruding a solid rectangle).
3. Extrude the sketch along the spar length (matches "Semi-span" in the simulator).
4. In the FeatureManager tree, expand **Solid Bodies**, right-click the body,
   choose **Rename**, and name it exactly **`Spar`** (the macro looks for this
   name to apply color).

## 2. Create the three global variables

1. **Tools → Equations** (or the *Equations, Global Variables, and Dimensions*
   icon in the Equations toolbar).
2. Click **Global Variables**, and add three, with units in millimeters:
   - `"SparWidth" = 320mm`
   - `"SparHeight" = 420mm`
   - `"WallThickness" = 13mm`
   (these starting values don't matter — the macro overwrites them on each run)
3. Now link your sketch dimensions to these variables. Double-click each
   dimension in your sketch and, instead of typing a number, type
   `="SparWidth"` (etc.) in the dimension box — SolidWorks will show a Σ
   symbol on dimensions that are equation-driven.
4. Click **OK** on the Equations dialog and confirm the part rebuilds cleanly.

## 3. Install the macro

1. **Tools → Macro → New**, save as `WingLoadSim_SolidWorksLink.swp`
   (or open the provided `.bas` file and paste its contents into the VBA editor:
   **Tools → Macro → Edit**, then File → Import File).
2. At the top of the macro, edit this line to match where your browser saves
   downloads:
   ```vb
   Const JSON_PATH As String = "C:\Users\YOURNAME\Downloads\wing_load_export.json"
   ```
3. Save.

## 4. Run it

1. In the web simulator, adjust inputs (or click **Optimize for Minimum Mass**
   first), then click **Export for SolidWorks** — this downloads
   `wing_load_export.json`.
2. In SolidWorks, with the spar part open: **Tools → Macro → Run**, select
   the macro.
3. The part rebuilds to the new dimensions and the `Spar` body recolors:
   - 🟢 green — FS ≥ 1.5 (within design margin)
   - 🟠 amber — 1.0 ≤ FS < 1.5 (below typical margin)
   - 🔴 red — FS < 1.0 (fails)

## Notes / limitations

- This is a one-way, on-demand link (export → run macro), not a live socket
  connection — that's a deliberate, honest simplification; a true live link
  would need a locally-installed bridge service, which is out of scope for a
  portfolio piece and not worth the added complexity it would demonstrate.
- The macro's JSON parsing is a minimal hand-rolled parser matching the fixed
  export schema (`wing-load-sim/solidworks-export/v1`) — it isn't a general
  JSON library, so it will break if the schema changes shape.
- Tested against SolidWorks' documented Equation Manager and `Body2.MaterialPropertyValues`
  API patterns; because this environment doesn't have SolidWorks installed,
  the macro hasn't been run end-to-end — validate it in your own install and
  adjust API calls if your SolidWorks version's syntax differs slightly.
