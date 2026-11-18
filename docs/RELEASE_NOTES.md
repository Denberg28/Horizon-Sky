Horizon Sky 0.1.0-rc.6 — fullscreen, line controls and aircraft handling

Fixes phone HUD and Sound labels wrapping vertically, oversized selectors and HUD remaining behind results. Adds compact menus, readable horizontal telemetry, fullscreen/expanding landscape canvas, display-safe margins and graduated gradient line sticks inspired by TeleRC Go. Stick endpoints map to full input, and new runs reset held power.

Trainer/jet now integrate lift, drag, thrust and gravity, with angle-of-attack stall response and damped control rates. Kestrel has stronger stability and quick propeller response; Peregrine has faster roll, higher wing loading and slower turbine spool. Nomad has independent thruster/coasting dynamics. The camera follows aircraft heading. Original reduced-order physics; not the Aerofly RC8 engine or validated real-aircraft behavior. No takeoff/landing, full 6-DOF aerobatics or orbits.

147/147 automated behavior/layout checks pass locally on Godot 4.6.3, plus Linux native visual review. Candidate publication additionally requires Windows package/startup and Android APK/signature CI. Target-device touch/cutout behavior, Windows/Android performance and physical USB-radio HIL remain unverified. Test candidate only.

Android ARM64 debug APK uses a temporary signing key. Upgrading may require uninstalling the previous test APK, erasing local progress. Windows is unsigned. Retain rc.5 and back up pilot saves before upgrading; restore matching saves for rollback. Schema 1 remains readable, but score comparisons across the handling change are not equivalent; old scores/unlocks are retained.
