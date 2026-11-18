Horizon Sky 0.1.0-rc.4 — Windows and Android test candidate

Adds Android ARM64 landscape debug APK with two virtual sticks: left yaw/throttle, right bank/pitch. Touch controls do not take over automatically from a selected USB radio. Pause button and focus loss freeze gameplay. The existing Windows version and save schema are preserved.

CI validates Godot import, automated tests, Windows package/startup and Android export/signature before publishing. Debug APK signing uses an ephemeral test key, not an upgrade-stable production identity. Android interactive performance, radio USB compatibility, and hardware input latency remain untested. Not a flight certification or stable Android release.

Install the attached APK by sideloading it on an Android ARM64 device. Newer APKs signed by a different key may require uninstall, which can delete local game progress. Use the previous rc.3 Windows release for rollback.
