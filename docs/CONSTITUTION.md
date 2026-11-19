# Horizon Sky flight-training constitution

Version 1.0 — 19 November 2026. Implements [Marlou Prompt Constitution v3.2](https://github.com/Denberg28/Agents_md/blob/main/Marlou_Prompt_Constitution_v3.md) and [upstream AGENTS.md v1.4](https://github.com/Denberg28/Agents_md/blob/main/AGENTS.md) together with repository AGENTS.md.

## Product purpose and physical transfer

Horizon Sky primarily builds fixed-wing RC Mode 2 stick familiarity. It is not certified pilot training, a replacement for Aerofly RC8, or a verified aerodynamic reproduction. RadioMaster Pocket USB Joystick is a supported target only after observed hardware calibration.

## Non-negotiable stick semantics

Left vertical: non-centering throttle (up increases power). Left horizontal: spring-centered rudder (right/right yaw). Right vertical: spring-centered elevator (down/back produces nose-up pitch). Right horizontal: spring-centered aileron (right/right bank). Internally preserve the semantic sequence (aileron, elevator, rudder, throttle) in all modes; never mistake RC channel numbers or HID axis numbers for semantic channel positions.

Map each radio axis visibly and validate direction, center, endpoints and low-throttle readiness before launch. No takeover by keyboard if radio goes missing; focus/device loss pauses and requires explicit resume.

## Flight training doctrine

Use proportional control and rate response, thrust-and-drag energy, banked lift, gravity, slip, stall and distinct trainer/jet behavior; do not snap direction to a waypoint or silently stabilize an attitude in ways that undermine real stick habits. Keep repeatable challenges and progression from wings-level and trim to shallow turns, coordinated rudder, climb/descend energy, crosswind and obstacle judgment. Pilot improvement is a hypothesis to test, not an automatic claim. Spacecraft is a separate optional entertainment mode.

## Sound, code and verification

Choose unobtrusive evolving low-register music rather than repeated high-pitched synth notes or gate-pass chirps; balance aircraft sounds above music and use impact and miss feedback sparingly. Use licensed assets with source/author credits or truly original music.

Keep small auditable sections, searchable tuning names and minimal patches. Preserve profile compatibility and control authority. Run import, deterministic tests and Windows/Android CI where applicable. Validate RadioMaster Pocket USB HID axes, latency, 20 disconnect/recovery cycles and human listening before stable promotion. Publish only honest candidate releases while HIL is missing; never invent measured skill transfer.
