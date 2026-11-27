#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 ]]; then
  printf 'Usage: %s /path/to/android_source.zip /path/to/Hexivra-petal-test.apk\n' "$0" >&2
  exit 2
fi

source_zip=$(realpath "$1")
apk=$(realpath -m "$2")
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

cd "$root"
tar -cf - --exclude='./.git' --exclude='./.godot' --exclude='./build' --exclude='./docs' \
  --exclude='./android' --exclude='./export_credentials.cfg' --exclude='*.keystore' \
  --exclude='*.jks' --exclude='./.env' . | tar -xf - -C "$scratch"

mkdir -p "$scratch/android/build" "$(dirname "$apk")"
unzip -q "$source_zip" -d "$scratch/android/build"
touch "$scratch/android/build/.gdignore"
godot --version | cut -d . -f 1-4 > "$scratch/android/.build_version"
install -D -m 644 "$root/android-petal/HexivraPetal.kt" \
  "$scratch/android/build/src/main/java/com/mhmmad/hexivra/ads/HexivraPetal.kt"

python3 - "$scratch" <<'PY'
from pathlib import Path
import sys

scratch = Path(sys.argv[1])
preset = scratch / "export_presets.cfg"
config = preset.read_text().replace("gradle_build/use_gradle_build=false", "gradle_build/use_gradle_build=true")
config = config.replace('package/unique_name="com.mhmmad.hexivra"', 'package/unique_name="com.mhmmad.hexivra.petaltest"')
config = config.replace('package/name="Hexivra"', 'package/name="Hexivra Petal Test"\npermissions/internet=true')
config = config.replace('version/name="2.0.0"', 'version/name="2.0.0-petal-test"')
preset.write_text(config)

build = scratch / "android/build"
manifest = build / "src/main/AndroidManifest.xml"
xml = manifest.read_text()
xml = xml.replace("    <application", """    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" tools:node="remove" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" tools:node="remove" />
    <uses-permission android:name="android.permission.READ_PHONE_STATE" tools:node="remove" />
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" tools:node="remove" />
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" tools:node="remove" />
    <uses-permission android:name="com.hihonor.permission.MANAGE_FOLD_SCREEN" tools:node="remove" />
    <uses-permission android:name="com.hihonor.permission.MANAGE_FOLD_SCREEN_PRIVILEGED" tools:node="remove" />

    <application""")
xml = xml.replace("        <profileable", """        <meta-data android:name="org.godotengine.plugin.v2.HexivraPetal"
            android:value="com.mhmmad.hexivra.ads.HexivraPetal" />
        <profileable""")
manifest.write_text(xml)

gradle = build / "build.gradle"
gradle.write_text(gradle.read_text() + """
repositories {
    maven {
        url = uri("https://developer.huawei.com/repo/")
        content { includeGroupByRegex("com[.]huawei([.].*)?") }
    }
}

dependencies {
    debugImplementation "com.huawei.hms:ads-banner:13.4.91.300"
    debugImplementation "com.huawei.hms:ads-interstitial:13.4.91.300"
    debugImplementation "com.huawei.hms:ads-consent:3.4.91.300"
}
""")
PY

godot --headless --editor --path "$scratch" --import --quit
godot --headless --path "$scratch" --export-debug Android "$apk"
test -s "$apk"
