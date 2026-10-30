#!/usr/bin/env bash
# Windows (Git Bash) build of launcher/build/dumbtv-home.apk, the same steps as build.sh.
# build.sh expects Unix paths and a `zip` binary; here the SDK's .jar tools run through the JDK
# directly and aapt adds classes.dex, so no zip is needed.
#   ANDROID_HOME  SDK with platforms;android-25 and build-tools;34.0.0
#   JAVA_HOME     a JDK 17
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# shellcheck disable=SC1091
source version.env
MIN_SDK=${MIN_SDK:-25}
TOOLS=${DUMBTV_TOOLCHAIN:-$HOME/.dumbtv-toolchain}
SDK=${ANDROID_HOME:-$TOOLS/sdk}
JAVA_HOME=${JAVA_HOME:-$(ls -d "$TOOLS"/jdk-17* | head -1)}
BT=$(ls -d "$SDK"/build-tools/* | sort -V | tail -1)
JAR=$SDK/platforms/android-$MIN_SDK/android.jar
[[ -f $JAR ]] || { echo "error: $JAR missing" >&2; exit 1; }
win() { cygpath -w "$1"; }
JAVA=$JAVA_HOME/bin/java

KEYSTORE=${DUMBTV_KEYSTORE:-$PWD/release.keystore}
KEYPASS=${DUMBTV_KEYPASS:-dumbtvhome}
if [[ ! -f $KEYSTORE ]]; then
  "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$(win "$KEYSTORE")" -alias home -keyalg RSA -keysize 2048 \
    -validity 10000 -storepass "$KEYPASS" -keypass "$KEYPASS" -dname "CN=dumbtv home" >/dev/null
  echo "created signing key $KEYSTORE (keep it: updates must be signed with the same key)"
fi

WORK=build/work
rm -rf "$WORK"
mkdir -p "$WORK/gen" "$WORK/classes" "$WORK/dex"

"$BT/aapt2" compile --dir res -o "$WORK/res.zip"
"$BT/aapt2" link -I "$(win "$JAR")" --manifest AndroidManifest.xml "$WORK/res.zip" \
  --min-sdk-version "$MIN_SDK" --target-sdk-version 28 \
  --version-code "$VERSION_CODE" --version-name "$VERSION_NAME" \
  --java "$WORK/gen" -o "$WORK/app.apk"

find src "$WORK/gen" -name '*.java' > "$WORK/sources.txt"
"$JAVA_HOME/bin/javac" --release 8 -Xlint:all -Xlint:-options -Werror -encoding UTF-8 \
  -classpath "$(win "$JAR")" -d "$WORK/classes" @"$WORK/sources.txt"

find "$WORK/classes" -name '*.class' > "$WORK/classes.txt"
"$JAVA" -cp "$(win "$BT/lib/d8.jar")" com.android.tools.r8.D8 --release --min-api "$MIN_SDK" \
  --lib "$(win "$JAR")" --output "$WORK/dex" @"$WORK/classes.txt"
(cd "$WORK/dex" && "$BT/aapt" add -k ../app.apk classes.dex >/dev/null)

"$BT/zipalign" -f -p 4 "$WORK/app.apk" "$WORK/aligned.apk"
"$JAVA" -jar "$(win "$BT/lib/apksigner.jar")" sign --ks "$(win "$KEYSTORE")" \
  --ks-pass "pass:$KEYPASS" --key-pass "pass:$KEYPASS" --out build/dumbtv-home.apk "$WORK/aligned.apk"
"$JAVA" -jar "$(win "$BT/lib/apksigner.jar")" verify build/dumbtv-home.apk
rm -rf "$WORK"
printf 'built build/dumbtv-home.apk  %s bytes\n' "$(wc -c < build/dumbtv-home.apk | tr -d ' ')"
