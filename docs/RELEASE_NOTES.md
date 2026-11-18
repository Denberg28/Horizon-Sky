Horizon Sky 0.1.0-rc.5 — Windows and Android test candidate

Adds original engine sound for each craft, with pitch following throttle and airspeed, plus gate pass/miss and debrief tones. The hangar and pause panel offer five saved sound presets, including mute. Pause, focus/device loss and hangar return stop flight audio. Older saves keep their flight records and default to Balanced sound. No audio downloads or new dependencies.

Local Godot 4.6.3 Linux headless checks pass 114/114 behavioral assertions, including generated PCM headroom, engine response, immediate mute/pause/focus silence, debrief cue isolation and sound preference recovery. CI must separately pass import, source checks, Windows export/package/startup and Android APK/signature verification for the delivered commit. Physical Windows/Android listening, manual play/performance and USB-radio HIL remain unverified. Candidate only; not a flight certification.

Android ARM64 landscape APK uses a temporary debug signing key, not an upgrade-stable production identity. A newer test APK may require uninstalling the previous one, which can erase its local progress. Windows is unsigned. Retain the previous rc.4 candidate and back up saves before upgrading; rollback using the retained build and matching saves.
