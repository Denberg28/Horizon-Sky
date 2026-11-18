# Changelog

## 0.1.0-rc.8 — 2026-11-19

- Added fading world-space wingtip contrails during actual speed-up, with bounded 30 Hz sampling and no false emission at steady speed.
- Replaced the shared decorative flame with power-responsive trainer propwash, jet exhaust and twin spacecraft thrusters; audio pitch/level follows actual engine spool power.
- Tuned cruise/maximum speeds to trainer 24/42 m/s, jet 50/96 m/s and spacecraft 42/115 m/s, with matched assisted thruster acceleration/braking.
- Effects freeze on pause and clear on new flight, menu and debrief; added speed-envelope, ribbon, exhaust-intensity and lifecycle regressions. Candidate pending physical-device performance/HIL validation.

## 0.1.0-rc.7 — 2026-11-19

- Enlarged graduated touch sticks by roughly 45% at the standard landscape canvas while keeping central instruments clear.
- Added a lower-center fighter-style compass/attitude/speed/altitude/power/vertical-speed/acceleration HUD.
- Increased aircraft thrust response above cruise and idle drag; spacecraft now uses assisted cruise with low-power reverse-thruster braking.
- Added five seeded track families with varied spacing, elevation, scenery and debris; Retry route preserves the seed while New route reshuffles.
- Replaced synthesized generic sound with Kenney sampled sci-fi effects and stage-specific orchestral music by Leonardo Paz, with in-game and packaged attribution/license/hash inventory.
- Added route stress, throttle-response, HUD spacing, imported-audio and scene-removal audio regressions. Candidate only; target-device validation remains pending.

## 0.1.0-rc.6 — 2026-11-19

- Fixed zero-width HUD/Sound labels, oversized selectors and HUD leaking into results. Added compact menus, shorter copy and consistent text/control sizes.
- Expanded the 1280×720 canvas to fill wide displays, added fullscreen startup and safe-area margins, and preserved resize/pause/debrief state.
- Replaced circular touch pads with graduated gradient line sticks and small position lights. Full input matches visible endpoints; restarting resets held power.
- Replaced target-velocity blending with original reduced-order aerodynamic forces for trainer/jet and separate spacecraft thrusters. Added gravity, lift/drag, stall response, angular damping, craft-specific stability/wing loading/spool and a heading-aligned chase view.
- Added physical-behavior and multi-size UI regressions. Candidate only; exact RC8 equivalence, real-aircraft fidelity and physical-device validation are not claimed.

## 0.1.0-rc.5 — 2026-11-19

- Added original synthesized engine loops for all three craft, responding smoothly to throttle and speed, plus gate pass/miss and debrief tones.
- Added saved sound presets in hangar and pause; older schema-1 profiles keep their records and default to Balanced.
- Pause, focus/device loss, menu return and shutdown stop flight audio; muting stops all voices immediately.
- Added sound synthesis, lifecycle and preference recovery checks; Android package metadata now matches the new game version.
- Candidate only; target Windows/Android listening, performance and physical USB validation remain unverified.

## 0.1.0-rc.4 — Android candidate

- Ported shared Godot gameplay to Android ARM64 with explicit two-finger touch authority, landscape controls, app focus pause and a touch guide.
- Added Android APK export with automated package/signature checks, while preserving Windows release and regression checks.
- Debug signing key is temporary; physical Android performance and controller tests remain unverified.

## 0.1.0-rc.3 — 2026-11-18

- Added three progressively harder training stages per world and craft: Foundations, Crosswind and Debris Run, with explicit score-based unlocking.
- Introduced learnable moving low-poly debris, stage-specific route geometry, wind and gate sizes.
- Improved live flight guidance: screen-space next-gate marker, attitude cue, progress strip, clean streaks, animated engine flare and contextual hit/miss feedback.
- Reworked hangar, calibration, pause and debrief to use bounded, scrollable panels with cleaner spacing and a readable flight log.
- Preserved 16-gate legacy Foundations records, schema-1 save compatibility and explicit USB input authority / freeze-on-loss safety.
- Extended simulated route, collision, hazard motion and unlock regression checks; physical USB and Windows interactive acceptance remain required for stable.

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
