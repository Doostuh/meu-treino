"""Copia o código nativo e ajusta o AndroidManifest depois do `npx cap add android`."""
import os, re, shutil
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "android", "app", "src", "main")
pkg_dir = os.path.join(APP, "java", "br", "adriano", "meutreino")
os.makedirs(pkg_dir, exist_ok=True)
for f in os.listdir(os.path.join(ROOT, "native", "java")):
    shutil.copy(os.path.join(ROOT, "native", "java", f), os.path.join(pkg_dir, f))
for sub in ("layout", "drawable"):
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
open(mf, "w", encoding="utf-8").write(s)
print("android patched")
