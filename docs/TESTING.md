## rc.3 new regression acceptance

Software tests now cover all nine world/stage route combinations (16 target gates and clearance), 15 stage-three moving hazards, hazard contact, progressing hazard coordinates and unlock thresholds (55/65). Manual Windows/HIL should additionally verify stage selector disabled states, unlock persistence after restart, paused hazard freeze, readable waypoint marker on all palettes, no obstruction at 1280×800, no off-screen menu controls, and 60 fps for 10 minutes with procedural debris enabled. These interactive/hardware checks are **NOT TESTED** until measured on the target PC and radio. Candidate CI status must be read from the observed run, not inferred from this document.

# Verification and hardware protocol

## Required gates

| Gate | Candidate requirement | Stable requirement |
| --- | --- | --- |
| A source/build | Clean Godot 4.6.3 import, source/accidental-secret checks, Windows export | Same on final source |
| B behavior | Calibration bounds, model/courses, scoring, pause/recovery and persistence automated checks | Same + manual play |
| C regression | Boot → setup → run → pause/resume → debrief → replay/hangar; no earlier game baseline | All flows on target Windows/radio |
| D integration | Simulated model/controller-loss states and Windows packaged headless startup | Actual USB path, device/focus lifecycle |
| E HIL | BLOCKED explicitly when no equipment; candidate only | Required physical channel, faults, latency/endurance PASS |
| F delivery | PE x86_64, EXE/PCK pair, archive/content hashes, commit/engine metadata, prerelease | Interactive install/upgrade/rollback PASS |

No physical outputs/firmware exist: actuator safety, FC/PWM interoperability and electrical/thermal checks are N/A. There are no app dependencies to audit beyond the pinned engine/toolchain; source checks do not substitute for an independent security audit. Self-review is labeled reviewed, not independent approval.

## Reproduce software checks

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/run_tests.gd -- --test
python3 scripts/check_source.py
godot --headless --path . -- --frames=120
godot --headless --path . -- --demo --frames=600
```

Use Godot 4.6.3. Tests require `--test`, using test-pilot.json and test-pilot.backup.json; ordinary pilot saves are never test fixtures. Behavioral tests cover normalization/low input/deadzone/endpoints/inversion, bad mapping data, disconnect refusal, straight/banked/climbing flight, bounded soak, swept gate crossing, route clearance/contact, validated persistence/backup, startup/run/pause/focus/recovery, terrain debrief, simulated complete route and menu/lab returns. Simulated crossings set craft positions deliberately; they are not proof a human completed a course.

CI logs import/tests/export and Windows smoke as workflow artifacts. Export/package scripts enforce executable architecture and content checksums, and include source SHA in BUILD_INFO.json. Required runtime errors block publication. Packaging/Windows PASS must come from observed CI, never from workflow configuration alone.

## Physical USB HIL — required before stable

Path: **radio sticks → radio USB joystick firmware → data USB cable → Windows HID/SDL → mapping/calibration → virtual craft/HUD**. No receiver, ELRS, MCU, FC or physical actuator involved. A radio, physical Windows PC and input timing camera are unavailable to the agent.

From source, run in PowerShell after extracting the package:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows_hil.ps1 -PackageDirectory C:\Games\HorizonSky-0.1.0-rc.2
```

The script verifies EXE/PCK hashes, opens the game and prompts for observed results/evidence. ExecutionPolicy Bypass applies to this single invocation of the reviewed local script. It does not change machine settings. The script saves a local timestamped JSON report tied to source/version; it does not upload anything. The same script is bundled under scripts/ in the ZIP.

1. Record PC/Windows/GPU/driver, radio model/firmware/USB mode, cable, source SHA, version, axis assignments/reversal and profile backup. Disconnect unrelated radios initially. Use keyboard and mouse to stop/pause as needed.
2. Map/calibrate all four channels; test endpoints/direction/center. A4: centered drift ≤0.04, centered endpoints ±0.98, throttle ≤0.02 / ≥0.98. Duplicate axes and insufficient travel must be rejected. High throttle/noncentered controls must block launch/resume.
3. Fly each craft; exercise each physical channel, neutral/low/high and reversal. Disconnect during bank; film ≥120 fps and measure device-loss-to-freeze ≤100 ms. Verify position/time freeze, keyboard cannot take over, and reconnect alone never resumes. Explicit centered/low-throttle resume only. Repeat 20 times, including changed device slot and a competing device.
4. Alt-Tab under input; focus loss must freeze within 100 ms. Focus return stays paused. Repeat five cycles. Close/relaunch with device connected and disconnected; always start in hangar.
5. At 1280×800 on all palettes, access every menu/lab control, read HUD/active gate, manually pass/miss gates, contact terrain, finish/debrief and replay with keyboard and radio. Complete at least one route manually for each craft/world pairing; record failures.
6. Ten-minute run: measure sustained ≥60 fps and p95 stick-to-display ≤50 ms using ≥120 fps capture; record method/sample count/values. Software timing logs alone are not end-to-end evidence.
7. Save/debrief, restart and confirm records. Back up saves, corrupt main while closed, verify backup recovery, restore originals. Extract clean package, verify metadata/hash, launch and repeat; test upgrade/rollback with save copies.
8. Training observations: five initial/five later same-course/craft runs. Record median gates/precision/contact rate and practice interval. These observations do not certify real aircraft proficiency.

Any critical/high defect blocks candidate/stable; fix, rerun affected software and HIL on final source. Missing required HIL/interactive evidence blocks stable. Record PASS / FAIL / NOT TESTED / BLOCKED with actual observations and evidence paths; N/A needs a reason. See EVIDENCE.md for observed agent results.

Keyboard regression: both WASD and arrows must produce identical pitch/bank; W/Up nose down, S/Down nose up. Combine same-direction aliases (output remains ±1), mixed opposite directions (zero), release to neutral, diagonal inputs, Z/C yaw and Q/E bounded throttle. Pressing keys while a radio is selected must never take authority. Automated tests inject physical key events through Godot Input; physical Windows key rollover/focus and target-layout checks remain required.

## rc.5 sound acceptance

Automated checks require three craft loops and four distinct event buffers, bounded 16-bit PCM amplitude with mix headroom, throttle/speed pitch response, immediate mute and pause silence, no paused restart when volume changes, correct craft stream after unmute, and completion feedback with engine stopped. Optional sound preferences must survive reload and tolerate old/malformed settings without losing records. Test saves stay isolated with `--test`.

On target Windows and Android, listen at a low device volume first: verify all craft engines change smoothly with power/speed, distinguish pass/miss/completion/failure, select each preset from hangar and pause, restart to confirm persistence, and mute to verify silence. Pause, switch apps, return to hangar and disconnect a selected Windows radio: sound must stop without stuck voices; focus/reconnect alone must not restart it. Repeat 20 cycles and measure the existing ten-minute performance target with sound enabled. Listening quality, device audio latency and phone performance remain NOT TESTED until observed on hardware.

## rc.6 layout and handling acceptance

`tests/run_tests.gd` includes: exact line endpoints and fresh-run throttle reset; trimmed flight, power-off glide, low-speed lift loss without a speed floor, stall separation, banked lift loss/right turn, jet/trainer roll/stability/spool differences, spacecraft coasting/thrust and 60/120 Hz consistency. All craft run the bounded 100-second soak. SubViewport fixtures at 1280×720, 1600×720, 1280×960 and 960×540 verify readable menu text, bounded selector heights, horizontal HUD text, pause-button clearance, hidden results HUD and no duplicate save on relayout.

Interactive target-device checks: fullscreen coverage at 16:9 and 20:9 without side bars; safe cutout/navigation margins; menus and optional guide accessible; two simultaneous touches across all endpoints, cancellation, focus loss and restart; clean paused/results overlays. Fly trainer and jet at trim, idle and full power; feel roll response and neutral recovery; bank without elevator and observe altitude loss; reduce speed and recover from a stall by lowering the nose and adding power. Spacecraft must coast with power off and not turn its path merely by rolling. Measure the existing ten-minute performance/input targets. Linux desktop preview is software visual evidence, not Android/Windows HIL or aircraft validation.

## rc.7 adventure acceptance

Automated checks require meaningful acceleration/deceleration within two seconds for trainer/jet, correctly signed acceleration, spacecraft low-power braking without gravity, enlarged stick hitboxes that clear central instruments on four canvases, identical route replay and changed new-route geometry. Stress 250 seeds × three worlds × three stages (2,250 configurations): 16 ordered gates, bounded lateral/climb increments, spacing and terrain clearance; cover all five families and actual seeded gate/pylon/debris separation on sampled builds.

All ten bundled Ogg resources must decode with positive duration. Asset inventory/credit/license identifiers and SHA256 hashes must match source. Test mute/pause/focus/scene removal across engine, cue and orchestral voices; a retiring ancestor must cancel native dispatch. Repeat the full software suite through multiple clean teardown cycles. Packaging includes credits/license inventory; in-game Audio credits identifies both creators and license URLs.

On physical Android/Windows: check the larger sticks at all edges with two fingers; central instrument readability; power-up/down feel on all craft; different new tracks and exact Retry route; ten-minute performance; loop transitions, music resume, mute and event balance at low device volume. Linux Dummy audio/visual checks do not measure listening quality or hardware latency.
