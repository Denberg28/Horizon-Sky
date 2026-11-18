"""Headless Android SDK path configuration for a Godot 4.6 test runner."""
from pathlib import Path
import re
import sys

java_home = Path(sys.argv[1]).resolve()
android_home = Path(sys.argv[2]).resolve()
assert (java_home / "bin" / "java").is_file()
assert (android_home / "platform-tools" / "adb").is_file()
settings_dir = Path.home() / ".config" / "godot"
files = list(settings_dir.glob("editor_settings-*.tres"))
assert files, "Godot editor settings not found after import"
p = files[-1]
content = p.read_text()
for key, value in (
    ("export/android/java_sdk_path", java_home),
    ("export/android/android_sdk_path", android_home),
):
    line = f'{key} = "{str(value)}"'
    expression = re.compile("^" + re.escape(key) + " = .*?$", re.MULTILINE)
    content = expression.sub(lambda _: line, content) if expression.search(content) else content.rstrip() + "\n" + line + "\n"
p.write_text(content)
print("PASS: Android SDK and JDK editor settings configured")
