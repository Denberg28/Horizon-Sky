# Definition and baseline

Repository: https://github.com/Denberg28/Horizon-Sky (public, main), empty on 7 November 2026. Rules bootstrap: `eff5755396a51ac5784bd69d208528b03ed2076c`. No known-good game, package identity or signing key exists. Starting rules retrieved from Denberg28/Agents_md/AGENTS.md, blob `a00e681e755ce38fe9ac0129efc43139536865fc`; preserved with project additions. User authorizes public source, commits, push and release builds.

Assumptions: native Windows x86_64, offline USB HID input, mouse/keyboard menus. Original faceted geometry and restrained palettes inspired by supplied images; screenshot content is not redistributed. Godot 4.6.3/GDScript provides free native rendering/input/export with one engine and no addons. A custom engine adds maintenance; Electron adds a runtime and browser/controller variation without benefiting this MVP.

MVP: three planet courses; trainer/jet/spacecraft profiles; 16 gates; terrain/pylon avoidance; chase view; input monitors; keyboard practice; device selection, four-axis calibration and inversion; explicit readiness/pause/recovery; scored debrief; best/attempt/last-result saves with recovery; Windows ZIP and CI.

Non-goals: certified flight training, realistic aerodynamics/orbits, combat, multiplayer, mission editor, force feedback, physical aircraft commands, RF/ELRS/SBUS/receivers, automatic radio firmware configuration, universal radio compatibility, paid assets/services, music/sound and stable promotion before HIL.

Flow: hangar → world/craft → controller lab as needed → readiness → course → debrief → replay/hangar. Esc, device removal or focus loss → frozen pause → explicit readiness → resume. Changed device ID → hangar/reselection. Corrupt save → backup/defaults; unwritable save → visible warning/playable session.

| ID | Measurable acceptance criteria |
| --- | --- |
| A1 | Godot 4.6.3 imports and required automated tests pass without script/runtime errors. |
| A2 | Each of three routes has 16 ordered gates clear of terrain/pylons; each craft stays finite during a 100-second scripted exercise. |
| A3 | Center, endpoints, reversal, deadzone and throttle normalization pass; duplicate/invalid/insufficient-travel calibration is rejected. |
| A4 | Actual USB signal path: all four channels reach expected directions and ±0.98 (throttle 0.02–0.98); center drift ≤0.04; other devices never take authority. Required HIL. |
| A5 | Device/focus loss freezes position/time within 100 ms on target PC. No automatic resume. 20 reconnect/resume cycles without errors. Required HIL. |
| A6 | Swept simulated crossings score 16 gates and reach debrief; terrain contact ends run; pause freezes model. |
| A7 | Disk restart retains best and attempts; corrupt main recovers backup; test runs never touch normal pilot save. |
| A8 | ZIP has x86_64 PE EXE + PCK, metadata and checksums; Windows headless packaged startup passes. Interactive Windows launch/play/debrief/restart required before stable. |
| A9 | At 1280×800 menus/lab accessible, HUD readable on every palette. On target PC: 60 fps over 10 minutes, p95 input-to-display ≤50 ms, measured using ≥120 fps capture. Hardware/performance validation required. |
| A10 | Training utility: five baseline and five later runs with same course/craft; compare median gates, center precision and contact rate. No skill-improvement claim without observations. |

Candidate gate: A1/A2/A3/A6/A7 and automated A8 pass; no known critical/high defects. Missing A4/A5/A8-interactive/A9-target remain explicit blockers to stable. A10 is an empirical limitation, not certification of skill transfer.
