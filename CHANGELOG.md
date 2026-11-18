## 0.1.0-rc.3 — 2026-11-18

- Added three progressively harder training stages per world and craft: Foundations, Crosswind and Debris Run, with explicit score-based unlocking.
- Introduced learnable moving low-poly debris, stage-specific route geometry, wind and gate sizes.
- Improved live flight guidance: screen-space next-gate marker, attitude cue, progress strip, clean streaks, animated engine flare and contextual hit/miss feedback.
- Reworked hangar, calibration, pause and debrief to use bounded, scrollable panels with cleaner spacing and a readable flight log.
- Preserved 16-gate legacy Foundations records, schema-1 save compatibility and explicit USB input authority / freeze-on-loss safety.
- Extended simulated route, collision, hazard motion and unlock regression checks; physical USB and Windows interactive acceptance remain required for stable.

# Changelog

## 0.1.0-rc.2 — 2026-11-07

- Added arrow-key pitch/bank controls alongside existing WASD, with identical directions and response.
- Moved keyboard rudder to Z/C; Q/E throttle, Esc pause and F11 fullscreen remain unchanged.
- Combined aliases without doubled output; opposing keys cancel across both layouts.
- Updated hangar control guide and added synthetic key-input regressions. USB radio mappings/save schema unchanged.
- Retains prerelease tier pending physical radio and Windows interactive HIL.

## 0.1.0-rc.1 — 2026-11-07

- First Windows test candidate from an empty repository.
- Original procedural polygon courses, three planet palettes/routes/wind profiles and three handling variants.
- USB joystick mapping, asymmetric calibration, inversion, input feedback and keyboard practice.
- Explicit authority/readiness, frozen pause on focus/device loss and manual recovery.
- Gate scoring, terrain/pylon contact, debriefs, best/attempt/last-result persistence and save recovery.
- Godot 4.6.3 setup, automated behavior checks, Windows export/package checks, CI prerelease delivery and executable HIL procedure.
- Stable blocked on physical radio and Windows interactive validation.
