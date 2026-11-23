"""Copia o código nativo e ajusta o AndroidManifest depois do `npx cap add android`."""
import os, re, shutil
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "android", "app", "src", "main")
pkg_dir = os.path.join(APP, "java", "br", "adriano", "meutreino")
os.makedirs(pkg_dir, exist_ok=True)
for f in os.listdir(os.path.join(ROOT, "native", "java")):
    shutil.copy(os.path.join(ROOT, "native", "java", f), os.path.join(pkg_dir, f))
for sub in ("layout", "drawable", "raw"):
    dst = os.path.join(APP, "res", sub); os.makedirs(dst, exist_ok=True)
    for f in os.listdir(os.path.join(ROOT, "native", "res", sub)):
        shutil.copy(os.path.join(ROOT, "native", "res", sub, f), os.path.join(dst, f))

mf = os.path.join(APP, "AndroidManifest.xml")
s = open(mf, encoding="utf-8").read()
perms = ["android.permission.VIBRATE", "android.permission.POST_NOTIFICATIONS", "android.permission.FOREGROUND_SERVICE",
         "android.permission.FOREGROUND_SERVICE_SPECIAL_USE", "android.permission.WAKE_LOCK"]
add = "".join(f'    <uses-permission android:name="{p}" />\n' for p in perms if p not in s)
s = s.replace("<application", add + "    <application", 1)
svc = '''
        <service android:name=".WorkoutService" android:exported="false" android:foregroundServiceType="specialUse">
            <property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE" android:value="Controle do treino de musculação na tela de bloqueio" />
        </service>
'''
if "WorkoutService" not in s:
    s = s.replace("</application>", svc + "    </application>", 1)
if "com.garmin.android.apps.connectmobile" not in s:
    s = s.replace("<application", '    <queries>\n        <package android:name="com.garmin.android.apps.connectmobile" />\n    </queries>\n    <application', 1)
open(mf, "w", encoding="utf-8").write(s)

# Connect IQ Mobile SDK (conversa com o app do relógio pelo Garmin Connect)
bg = os.path.join(ROOT, "android", "app", "build.gradle")
g = open(bg, encoding="utf-8").read()
dep = 'implementation "com.garmin.connectiq:ciq-companion-app-sdk:2.4.0"'
if dep not in g:
    g = re.sub(r"dependencies\s*\{", "dependencies {\n    " + dep, g, count=1)
# Assinatura sempre com a mesma chave (ci/debug.keystore) para o Android aceitar instalar por cima
ks = os.path.join(ROOT, "ci", "debug.keystore").replace("\\", "/")
if "signingConfigs.fixo" not in g:
    g = g.replace("buildTypes {", """signingConfigs {
        fixo {
            storeFile file("%s")
            storePassword "android"
            keyAlias "androiddebugkey"
            keyPassword "android"
        }
    }
    buildTypes {
        debug { signingConfig signingConfigs.fixo }""" % ks, 1)
# versionCode crescente a cada build (número da execução do CI)
g = re.sub(r"versionCode \d+", 'versionCode Integer.parseInt(System.getenv("VC") ?: "1")', g, count=1)
g = re.sub(r'versionName "[^"]*"', 'versionName "2.7." + (System.getenv("VC") ?: "0")', g, count=1)
open(bg, "w", encoding="utf-8").write(g)
print("android patched")
