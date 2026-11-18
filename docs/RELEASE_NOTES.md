Horizon Sky 0.1.0-rc.8 — acceleration contrails and power exhaust

Adds fading world-space wingtip contrails during actual acceleration. Exhaust now varies with actual engine spool power: faint trainer propwash, bright jet plume and twin spacecraft thrusters. Exhaust length/width/opacity/emission change with power, and engine audio follows actual spool response. Trails are bounded, freeze with pause and clear on restart/menu/debrief.

Game cruise / maximum speeds: Kestrel 24/42 m/s; Peregrine 50/96 m/s; Nomad 42/115 m/s. The trainer is more forgiving, the jet stays faster and the assisted spacecraft has a higher speed range with matched acceleration/braking. The selector shows cruise speed and the HUD reports actual speed. These are reduced-order gameplay envelopes and stylized acceleration trails, not real-aircraft operating limits or a meteorological contrail model.

191/191 behavior checks pass locally on official Godot 4.6.3, including speed caps, exhaust/ribbon behavior and lifecycle regressions. Linux phone-shaped native visual review observed jet trails/exhaust. Candidate publication requires Windows package/startup and Android APK/signature CI. Physical-device performance, touch, listening quality and USB HIL remain unverified.

Android debug signing is temporary; an upgrade may require uninstalling the previous APK and erasing local progress. Windows is unsigned. Retain rc.7 and matching pilot backups for rollback. Existing scores/unlocks remain, with handling-version comparisons limited.
