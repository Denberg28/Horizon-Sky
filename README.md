# Horizon Sky

**A small world. A sharper pilot.** An offline Windows flight-skills game for USB radio controllers, with original procedural polygon art.

**0.1.0-rc.2 — TEST CANDIDATE.** Physical radio compatibility and interactive Windows graphics/performance remain unvalidated. This is an arcade training game, not a certified simulator or proof of real flight proficiency.

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

Bank causes a turn; level wings do not restore heading. Pitch holds its last angle when centered. All craft maintain forward speed at low throttle. Missed gates do not end a run. Terrain contact, airspace limits (±145 m lateral / 180 m altitude), or 180 seconds end the session. No commands are sent to physical equipment.

**Device/focus loss freezes flight.** Reconnect the same radio, center controls, lower throttle, explicitly resume. No automatic keyboard takeover. If the transient device ID changes, return to hangar and explicitly select the radio again. Identical devices may share a profile; validate each separately.

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

Tests require `--test` and isolate profile writes. `-- --demo --frames=600` enables a visual-smoke autopilot; it does not prove manual playability or training benefit.

CI verifies vendor SHA512 downloads, imports, behavior/source checks, Windows export/PE/archive/checksum validation and packaged Windows headless startup. Only then does main publish an immutable prerelease. Stable promotion is intentionally absent until required device validation passes.

See [spec](docs/SPEC.md), [architecture](docs/ARCHITECTURE.md), [tests/HIL](docs/TESTING.md), [limitations](docs/KNOWN_ISSUES.md) and [release notes](docs/RELEASE_NOTES.md).
