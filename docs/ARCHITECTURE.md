## rc.3 stage progression

The stage index is a transient menu selection (0–2); `course.gd` owns stage metadata, stage-dependent ring sizes/wind and deterministic moving polygon hazards. `main.gd` owns unlocks and stores distinct stage records via the existing schema-1 dictionary. Foundations uses its rc.2 key for backwards compatibility. Unlock thresholds are based on existing `best` scores (55, then 65); incomplete attempts cannot reach 55 because they are halved. Stage debris moves only inside `FLYING`, so focus/device pause freezes hazards as well as flight and score. `hud.gd` receives read-only flight/progress/screen-space waypoint cues; it cannot change control authority.

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
| flight_audio.gd | Three generated PCM engine loops, four event tones, two bounded playback voices; no control authority |

Only one input authority is selected. Missing radio returns zero and main freezes simulation before any further movement. No silent fallback/reconnect resume. Polling current engine state each tick avoids queued app commands. GUID/name guard against unrelated device-slot reuse; identical devices remain indistinguishable. Reselection must validate a saved mapping or calibrate anew.

There are no physical/RF/actuator outputs. Safe state is frozen virtual position, time and scoring. No physical command watchdog applies. A frozen driver that leaves a radio enumerated with stale axis values cannot be detected reliably: constant stick values are valid. Device removal events and connected-device checks are used; Windows latency is not claimed until measured.

Calibration: asymmetric min/center/max spans, rescaled 4% deadzone for centered axes, continuous endpoint throttle, inversion after normalization. Distinct in-range axes and ≥0.15 travel on each side of center are required. Samples are taken at render updates; sweep slowly. Four independently exposed axes are mandatory.

Flight model (rc.6): point-mass force integration at 120 Hz. Trainer/jet use air-relative dynamic pressure, lift perpendicular to flow and bank, quadratic parasite/induced/separation drag, thrust along the nose, gravity and sideslip damping. Cruise at 35% power is the trim reference. Above-cruise thrust gains make acceleration more pronounced; below-cruise idle drag and faster spool-down strengthen deceleration without resetting velocity. Elevator changes angle of attack via damped angular rates; surface authority varies with airspeed. Excess AoA reduces lift and raises drag. There is no artificial minimum forward speed or velocity-to-heading interpolation. Kestrel has stronger dihedral/stability, lower wing loading and a quick propeller response. Peregrine has faster roll, higher stall speed/wing loading and slower turbine spool. Nomad instead uses an assisted axial cruise controller: 35% holds starting cruise; higher power accelerates and lower power applies reverse-thruster braking, with RCS lateral damping and no wing lift/gravity/bank turning. Speed caps and ±1.3 rad pitch limits bound this reduced-order course game; it is not complete 6-DOF flight or an RC8 engine reproduction. The chase camera looks along actual aircraft heading. Planets still vary palette/course/wind rather than scientific gravity/atmosphere.

Reference principles, with independently authored code and tuning: [NASA lift equation](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/lift-equation/), [Aerofly control axes](https://www.aerofly.com/tutorials/mini-tutorials/axis/), [Aerofly angle of attack and stall](https://www.aerofly.com/tutorials/mini-tutorials/stream-drag-lift/), and [official RC8 manual](https://www.ikarus.net/downloads/manuals/RC8_manual_en_web.pdf). These sources do not validate Horizon Sky against RC8 or a physical aircraft.

UI uses an expanding 1280×720 canvas, desktop fullscreen and Android display-safe margins. Freestanding/HBox labels do not autowrap; wrapped prose belongs in bounded VBox containers. Selectors have fixed minimum touch height and no longest-item width expansion. Two explicit horizontal telemetry labels keep their own widths. HUD/touch/audio visibility follows flight state; debrief relayout renders saved results without recording another attempt. Line-stick visuals and hit testing share a single travel function; endpoints produce full command. Two-finger ownership is cleared on pause/focus loss; drag events cannot claim a new pointer after cancellation. New runs reset held power to 35%.

Gate scoring interpolates exact z-plane crossing and applies a 1.5 m center margin; wings/ring walls are not colliders. Terrain uses its analytic height; pylons use a conservative cone envelope. Active rings are brighter, passed green, missed red.

Score = passed-gate share ×65 + precision ×25 + smoothness ×10; incomplete sessions receive half. Precision averages all gates, including misses. Smoothness is input variation per second, a heuristic affected by device noise. Clearance/time are feedback, not speed rewards. Same planet/craft key retains attempts, best and last debrief.

Schema 1 contains controllers keyed by GUID/name and records keyed by planet/craft. Reads bounded to 1 MiB; invalid shape/types rejected. Write temp → flush/close → validate → copy valid prior main to backup → rename replacement. One process only; no concurrent-write transaction guarantee. Storage errors are visible and leave gameplay usable.

No network, analytics, arbitrary script loading, shell calls or secrets. CI uses pinned actions, official engine/template checksums, read-only build permissions, and a separate authorized prerelease publication job. No signing continuity exists; candidate is unsigned.

Keyboard map (rc.2): WASD and arrow keys are aliases for pitch/bank; Z/C yaw, Q/E throttle. Each direction ORs aliases before subtracting the opposite direction, keeping output bounded without duplicate-key gain. Physical key positions are used for layout-independent WASD. W/Up push nose down; S/Down pull nose up. Keyboard polling runs only for explicit keyboard authority.

Sound preferences are optional `settings.audio_volume` in schema 1. Missing/invalid preferences default to 0.45 without discarding controller/flight records; finite numeric values clamp to [0,1]. Preset selection writes once per choice, never per frame.

Audio uses three bounded voices: sampled engine loop, replaceable event cue and stage-specific orchestral Ogg track. Kenney Sci-fi Sounds is CC0; Leonardo Paz's Outer Space Music Pack is used under CC BY 4.0. Original audio files are unchanged; runtime loop/pitch/volume settings are applied to per-instance streams. Source hashes and attribution are pinned in `assets/audio/manifest.json` / `CREDITS.txt`; credits are available in-game and in both packages. Maximum channel gains sum to 0.90 before master volume. All starts are coalesced to render dispatch; pause/mute/focus/device loss cancels queued work and stops playback. Music keeps its playback position for resume, while a new session selects and restarts its stage track. Dispatch also checks queued ancestor deletion to prevent starting native playback in a retiring scene. No downloads or network calls occur in game.

Route generation has an independent seeded RNG and five pattern families, with stage-bounded lateral/vertical increments, varying 98–126 m spacing, an approachable first gate and at least 24 m analytic terrain clearance. Scenery and stage-three hazard shape/motion vary reproducibly with the same seed. `start_run(true)` chooses a new seed; `start_run(false)` preserves it. Debrief records the seed/family in the existing schema-1 last result; world/craft/stage score keys are retained. Rebuilding menus or resizing never changes the current seed or adds another attempt.

The lower-center HUD uses a bounded instrument rectangle between enlarged line-stick hitboxes. Compass/attitude/speed/altitude/power/vertical speed and actual speed-change-per-second are read-only. It is game feedback, not certified avionics.
