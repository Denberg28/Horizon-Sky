Horizon Sky 0.1.0-rc.2 — TEST CANDIDATE

Keyboard update: use WASD or arrow keys for pitch/bank; W/Up nose down, S/Down nose up, A/Left bank left, D/Right bank right. Z/C controls rudder and Q/E controls throttle. Keyboard is the default input mode. Duplicate directions do not double response; opposing directions cancel. Existing radio profiles and schema-1 saves remain compatible. The previous rc.1 package is retained for rollback.

Original minimal polygon flight game for Windows x86_64. Terra, Ares and Europa courses; Kestrel trainer, Peregrine jet and Nomad spacecraft; 16 gates, terrain/pylon avoidance, live input feedback and local debrief/records. USB joystick mapping/inversion/calibration, keyboard practice, explicit pause/recovery and validated save backup.

Publication requires automated source/behavior/package gates and packaged Windows headless startup. These are software checks, not HIL. BUILD_INFO.json ties the artifact to source/engine; SHA256SUMS.txt verifies the ZIP.

Required physical USB radio and Windows interactive/performance checks are BLOCKED pending equipment. RadioMaster Pocket compatibility and training benefit remain unvalidated. Controlled testing only; arcade game, not certified flight simulator.

Extract all files and run HorizonSky.exe beside HorizonSky.pck. Select USB Joystick mode on radio, map/calibrate all channels, confirm directions, center controls and lower throttle before launch. Follow bundled README and docs/TESTING.md for validation.

Upgrade into a separate folder; retain previous package and back up %APPDATA%\Godot\app_userdata\Horizon Sky\pilot.json and pilot.backup.json. Roll back by running retained version and restoring compatible saves. No earlier known-good game exists. Unsigned, Windows 10/11 x86_64/OpenGL 3.3 target; no paid service or installer.
