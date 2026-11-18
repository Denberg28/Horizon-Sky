# Horizon Sky

**A small world. A sharper pilot.** An offline Windows flight-skills game for USB radio controllers, with original procedural polygon art.

**0.1.0-rc.6 — TEST CANDIDATE.** Physical radio compatibility and interactive Windows graphics/performance remain unvalidated. This is a flight-skills game, not a certified simulator or proof of real flight proficiency.

## Play

1. Download the Windows x86_64 ZIP from [Releases](https://github.com/Denberg28/Horizon-Sky/releases), compare SHA256 with `SHA256SUMS.txt`, and extract everything. Keep `HorizonSky.exe` and `HorizonSky.pck` together; run the EXE. No engine installation, account or network needed. The executable is unsigned.
2. Choose Terra, Ares or Europa, then Kestrel trainer, Peregrine jet or Nomad spacecraft.
3. Open **Controller setup & calibration**. Connect a data-capable USB cable and select USB Joystick mode on your radio. RadioMaster Pocket needs its supported data USB connection; this game does not use ELRS or a receiver.
4. Select the device. Map roll/pitch/yaw/throttle to four distinct axes; watch live values and reverse channels as needed. Start range capture, sweep all channels fully several times, center roll/pitch/yaw, then capture center & save. Lower throttle afterward. Confirm output directions before launch.
5. Fly through the illuminated gate, look ahead to the next turn and avoid terrain/pylons. Debrief shows gates, precision, smoothness, time and clearance. Best scores, attempts and last results persist locally.

| Control | Keyboard | Positive radio output |
| --- | --- | --- |
| Bank | A / D or ← / → | Right bank |
| Pitch | W / S or ↑ / ↓ | Climb (S / ↓ = pull back; W / ↑ = nose down) |
| Rudder | Z / C | Turn right |
| Throttle | Q / E | Faster |
| Pause / resume | Esc | Mouse UI |
| Fullscreen | F11 | Mouse UI |

**Keyboard is the default input mode**; no radio is needed. If a radio was selected, choose Keyboard practice in Controller setup. WASD and arrows may be mixed; opposite directions cancel and duplicate direction keys do not increase input. Arrow left/right now bank; rudder has moved to Z/C.

Trainer and jet use lift, drag, thrust and gravity: ailerons command roll rate, elevator changes angle of attack, banking reduces vertical lift and low power leads to a glide. Kestrel has stronger stability and a faster propeller response; Peregrine rolls faster, has higher wing loading and a slower turbine spool. Nomad uses thruster acceleration and coasts at zero power, without wing lift or bank-to-turn coupling. These are original reduced-order models, not the Aerofly RC8 physics engine; no real-aircraft fidelity is claimed. Missed gates do not end a run. Terrain contact, airspace limits (±145 m lateral / 180 m altitude), or 180 seconds end the session. No commands are sent to physical equipment.

**Device/focus loss freezes flight.** Reconnect the same radio, center controls, lower throttle, explicitly resume. No automatic keyboard takeover. If the transient device ID changes, return to hangar and explicitly select the radio again. Identical devices may share a profile; validate each separately.

## Staged training (rc.3)

Choose **Foundations** (wide gates), **Crosswind** (narrower gates and increased drift), or **Debris Run** (tight gates and moving polygon debris). Score at least **55/100** in Foundations to unlock Crosswind; score **65/100** in Crosswind to unlock Debris Run, separately for each planet/craft. An existing rc.2 flight log is retained: its original record key counts as Foundations. All stages keep 16 gates and the same 180-second limit. A light HUD target marker, attitude line, streak counter, progress strip, and animated engine flare support look-ahead without adding menus while flying. Scores are heuristic practice feedback, not real-flight certification.

## Android test APK (rc.4)

The shared offline Godot game now supports Android ARM64 in landscape orientation. Download the latest Android APK from [Releases](https://github.com/Denberg28/Horizon-Sky/releases) and install it through the Android browser/file manager. On-screen touch controls are the supported Android input: left line stick for rudder/power and right for aileron/elevator, with a visible PAUSE button. Throttle holds its setting on release; other axes return to neutral. Loss of app focus pauses the game.

This is a **debug-signed test APK**, not a Play Store or stable build. The CI test signing key is temporary and differs between builds. An Android upgrade may require uninstalling the old test APK, which can erase local saves. Android radio/controller compatibility and real phone performance have not been verified. The Android pilot save is independent of the Windows save.

## Fullscreen and controls (rc.6)

The scene fills landscape displays, including wide phones, without fixed-aspect side bars. Menus use short labels and bounded selectors; the HUD uses two horizontal readouts and disappears on pause/results. Windows launches fullscreen; F11 toggles windowed mode. Android retains immersive landscape mode and uses display-safe margins.

Touch sticks use transparent graduated cross-lines with small position lights, based on the TeleRC Go line style. The visible endpoints map to full input. Power holds on release; the other axes center. A fresh run resets power to 35%; app focus loss clears gesture ownership. Optional **Controls** contains the short guide.

## Flight sound (rc.5)

Each craft has an original synthesized engine loop whose pitch follows throttle and airspeed. Short tones signal gate passes, misses, course completion and failed runs. Choose **Muted**, **Quiet**, **Balanced** (default), **Loud** or **Full** in the hangar or pause panel; the preference saves locally. Pausing, losing app focus or disconnecting the selected radio stops flight audio immediately. Returning focus does not resume it. There are no audio downloads or music tracks.

## Compatibility and storage

Target: Windows 10/11 x86_64 with OpenGL 3.3 capable graphics, keyboard/mouse, optional USB joystick. Four independent axes must be exposed to Godot's input interface. Detection alone is not compatibility; generic HID radios, firmware modes and axis ordering need controller-lab/HIL verification. Other CPU architectures and non-USB radio transports are outside this candidate.

Windows saves: `%APPDATA%\Godot\app_userdata\Horizon Sky\pilot.json` and `pilot.backup.json`. Profiles use GUID + device name. No cloud or telemetry. Corrupt files recover from a validated backup or defaults; write errors are visible and do not stop play. Run one instance at a time.

Upgrade: close the game, back up both saves, extract the new version into a separate folder. Retain old ZIP and saves. Rollback: run the retained version and restore matching saves if necessary. Schema 1; no earlier game release/signing identity exists.

## Development

Godot **4.6.3 stable**, standard GDScript build and matching official export templates. Compatibility renderer, no addons or package dependencies. Python 3.11+ for packaging/checks.

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/run_tests.gd -- --test
python3 scripts/check_source.py
godot --path .
godot --headless --path . --export-release "Windows Desktop" build/HorizonSky.exe
python3 scripts/package.py --commit YOUR_COMMIT_SHA
```

Tests require `--test` and isolate profile writes. `-- --touch-preview` explicitly selects touch controls for desktop layout review. `-- --demo --frames=600` enables a visual-smoke autopilot; it does not prove manual playability or training benefit.

CI verifies vendor SHA512 downloads, imports, behavior/source checks, Windows export/PE/archive/checksum validation and packaged Windows headless startup. Only then does main publish an immutable prerelease. Stable promotion is intentionally absent until required device validation passes.

See [spec](docs/SPEC.md), [architecture](docs/ARCHITECTURE.md), [tests/HIL](docs/TESTING.md), [limitations](docs/KNOWN_ISSUES.md) and [release notes](docs/RELEASE_NOTES.md).
