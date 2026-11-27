#!/bin/sh
# Сборка debug-APK headless (для CI). Аргументы: путь_к_godot путь_к_apk
# Нужны: JAVA_HOME (JDK 17+), ANDROID_HOME (build-tools + platform-tools),
# шаблоны экспорта Godot 4.7.2 (android_debug.apk) в ~/.local/share/godot/export_templates/4.7.2.stable
set -e
GODOT="$1"
OUT="$2"
KS="${DEBUG_KEYSTORE:-$HOME/.android/godot-debug.keystore}"
mkdir -p "$(dirname "$KS")" "$(dirname "$OUT")"
if [ ! -f "$KS" ]; then
  "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$KS" -storepass android -alias androiddebugkey \
    -keypass android -keyalg RSA -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi
# создать файл настроек редактора, затем вписать пути (Godot перезаписывает свои настройки при выходе)
"$GODOT" --headless --editor --quit >/dev/null 2>&1 || true
ES=$(ls "$HOME"/.config/godot/editor_settings-4*.tres | head -1)
grep -v -e '^export/android/android_sdk_path' -e '^export/android/java_sdk_path' -e '^export/android/debug_keystore' "$ES" > "$ES.tmp"
{
  cat "$ES.tmp"
  echo "export/android/android_sdk_path = \"$ANDROID_HOME\""
  echo "export/android/java_sdk_path = \"$JAVA_HOME\""
  echo "export/android/debug_keystore = \"$KS\""
  echo "export/android/debug_keystore_user = \"androiddebugkey\""
  echo "export/android/debug_keystore_pass = \"android\""
} > "$ES"
rm "$ES.tmp"
"$GODOT" --headless --export-debug "Android" "$OUT"
test -f "$OUT"
echo "APK: $OUT"
