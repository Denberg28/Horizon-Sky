# Open validation and limitations

No known critical/high defects after recorded software checks; missing verification is not compatibility evidence.

- BLOCKED: physical RadioMaster Pocket/generic USB joystick HIL, Windows interactive rendering/manual play, input/disconnect latency and repeated device cycles. No such hardware is available to the agent.
- NOT TESTED: target-PC ten-minute performance and observed training benefit. Windows CI headless startup is not interactive validation.
- Four independent engine-exposed axes required. Device/firmware axis enumeration varies. Identical USB devices and an enumerated-but-frozen driver cannot always be distinguished.
- Forward arcade handling; no takeoff/landing/stall/6-DOF/orbits. Trainer/jet/spacecraft share controls and vary speed/response/inertia.
- Cone envelopes are conservative around polygon faces; wingtip-only impacts/ring-wall collision are not modeled. Analytic terrain contact can differ slightly from rendered triangles.
- Menus target 1280×800 and a 16:10 logical canvas. Other aspect ratios change framing; lower resolutions not validated.
- No sound/music; unsigned executable. One instance at a time; back up saves before upgrade/downgrade.
