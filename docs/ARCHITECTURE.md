# Architecture

Native Godot Compatibility/OpenGL scene, original geometry, 120 Hz fixed simulation; no external models/textures/plugins. Rendering follows the display update rate.

| Component | Responsibility / interface |
| --- | --- |
| main.gd | MENU / FLYING / PAUSED / RESULTS; UI, camera, scoring, lifecycle |
| radio_input.gd | Selected authority; four-channel mapping/calibration; read(dt) returns roll/pitch/yaw [-1,1], throttle [0,1] |
| flight_model.gd | Deterministic step(command, dt, wind); metres, seconds, radians; bounded finite inputs |
| course.gd | Seeded terrain/gates/pylons; analytic ground/cone-envelope contact |
| profile_store.gd | Schema-validated bounded JSON, temp/readback/backup/replace and recoverable errors |
| hud.gd | Reticle and Mode-2-style stick monitors; no authority |

Only one input authority is selected. Missing radio returns zero and main freezes simulation before any further movement. No silent fallback/reconnect resume. Polling current engine state each tick avoids queued app commands. GUID/name guard against unrelated device-slot reuse; identical devices remain indistinguishable. Reselection must validate a saved mapping or calibrate anew.

There are no physical/RF/actuator outputs. Safe state is frozen virtual position, time and scoring. No physical command watchdog applies. A frozen driver that leaves a radio enumerated with stale axis values cannot be detected reliably: constant stick values are valid. Device removal events and connected-device checks are used; Windows latency is not claimed until measured.

Calibration: asymmetric min/center/max spans, rescaled 4% deadzone for centered axes, continuous endpoint throttle, inversion after normalization. Distinct in-range axes and ≥0.15 travel on each side of center are required. Samples are taken at render updates; sweep slowly. Four independently exposed axes are mandatory.

Arcade handling: roll commands bank angle and a turn; pitch/yaw command angular rates. Pitch/heading bounded for forward course progression. Craft vary speed/response/inertia; Nomad carries momentum longer. Planets vary palette/route/wind, not scientific gravity/atmosphere. Gate scoring interpolates exact z-plane crossing and applies a 1.5 m center margin; wings/ring walls are not colliders. Terrain uses its analytic height; pylons use a conservative cone envelope. Active rings are brighter, passed green, missed red.

Score = passed-gate share ×65 + precision ×25 + smoothness ×10; incomplete sessions receive half. Precision averages all gates, including misses. Smoothness is input variation per second, a heuristic affected by device noise. Clearance/time are feedback, not speed rewards. Same planet/craft key retains attempts, best and last debrief.

Schema 1 contains controllers keyed by GUID/name and records keyed by planet/craft. Reads bounded to 1 MiB; invalid shape/types rejected. Write temp → flush/close → validate → copy valid prior main to backup → rename replacement. One process only; no concurrent-write transaction guarantee. Storage errors are visible and leave gameplay usable.

No network, analytics, arbitrary script loading, shell calls or secrets. CI uses pinned actions, official engine/template checksums, read-only build permissions, and a separate authorized prerelease publication job. No signing continuity exists; candidate is unsigned.

Keyboard map (rc.2): WASD and arrow keys are aliases for pitch/bank; Z/C yaw, Q/E throttle. Each direction ORs aliases before subtracting the opposite direction, keeping output bounded without duplicate-key gain. Physical key positions are used for layout-independent WASD. W/Up push nose down; S/Down pull nose up. Keyboard polling runs only for explicit keyboard authority.
