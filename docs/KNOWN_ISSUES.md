# Open validation and limitations

No known critical/high defects after recorded software checks; missing verification is not compatibility evidence.

- BLOCKED: physical RadioMaster Pocket/generic USB joystick HIL, Windows interactive rendering/manual play, input/disconnect latency and repeated device cycles. No such hardware is available to the agent.
- NOT TESTED: target-PC ten-minute performance and observed training benefit. Windows CI headless startup is not interactive validation.
- Four independent engine-exposed axes required. Device/firmware axis enumeration varies. Identical USB devices and an enumerated-but-frozen driver cannot always be distinguished.
- Original reduced-order dynamics; not an Aerofly RC8 engine port. No takeoff/landing, complete 6-DOF rigid-body physics, spins, structural loads or orbital mechanics. Pitch is limited to ±1.3 rad; trainer/jet atmosphere/gravity do not change by planet. Real-aircraft/control fidelity remains unvalidated.
- Cone envelopes are conservative around polygon faces; wingtip-only impacts/ring-wall collision are not modeled. Analytic terrain contact can differ slightly from rendered triangles.
- Expanding 1280×720 logical canvas. Automated UI geometry covers 1280×720, 1600×720, 1280×960 and 960×540. Linux native visual review covers standard/phone-shaped canvases; physical Android cutouts, navigation gestures and target-device font rendering remain unverified.
- Sampled engine/effect sound and orchestral music are bundled; target-device listening/mix quality and audio latency are unverified. Unsigned Windows executable. One instance at a time; back up saves before upgrade/downgrade.
- New stage progression, procedural debris and responsive menus need interactive Windows visual/performance testing. Use the rc.6 multi-size checks as software evidence; target-device interaction remains unverified.
- Moving debris is simulated by simple deterministic oscillation and sphere collision, not orbital physics; training transfer remains unmeasured.

- Random routes are bounded by geometric checks, not proof of manual flyability on every seed/craft. Retry preserves a route for practice; compare scores across randomized layouts cautiously.
- Spacecraft uses assisted cruise/braking for throttle responsiveness; it is not free Newtonian/orbital flight. Flight HUD values are game measurements, not certified instrumentation.
