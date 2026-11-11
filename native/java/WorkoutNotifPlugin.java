package br.adriano.meutreino;

import android.Manifest;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.ContentValues;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/**
 * Ponte entre o app web e a notificação de treino (tela de bloqueio).
 * JS chama update() a cada mudança; ações tocadas na notificação voltam pelo evento "action".
 */
@CapacitorPlugin(name = "WorkoutNotif")
public class WorkoutNotifPlugin extends Plugin {

    static WorkoutNotifPlugin instance;

    @Override
    public void load() {
        instance = this;
    }

    static void emit(JSObject data) {
        if (instance != null) instance.notifyListeners("action", data, true);
    }

    @PluginMethod
    public void requestPermission(PluginCall call) {
        if (Build.VERSION.SDK_INT >= 33 &&
                ContextCompat.checkSelfPermission(getContext(), Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(getActivity(), new String[]{Manifest.permission.POST_NOTIFICATIONS}, 4711);
        }
        call.resolve();
    }

    @PluginMethod
    public void update(PluginCall call) {
        WorkoutService.State st = WorkoutService.STATE;
        st.title = call.getString("title", "Treino");
        st.exercise = call.getString("exercise", "");
        st.setLabel = call.getString("setLabel", "");
        st.next = call.getString("next", "");
        st.key = call.getString("key", "");
        // Lê os números direto do JSON: valores inteiros grandes (como o horário em ms)
        // chegam como Long e o getDouble/getInt do PluginCall os ignora.
        JSObject d = call.getData();
        st.kg = d.optDouble("kg", 0.0);
        st.reps = d.optInt("reps", 0);
        st.kgStep = d.optDouble("kgStep", 2.5);
        st.restSec = d.optInt("restSec", 0);
        st.finished = d.optBoolean("finished", false);
        st.sound = d.optBoolean("sound", true);
        st.restEnd = (long) d.optDouble("restEnd", 0.0);
        Sounds.useAlarm = d.optBoolean("alarm", false);
        Intent i = new Intent(getContext(), WorkoutService.class);
        i.setAction(WorkoutService.ACTION_REFRESH);
        ContextCompat.startForegroundService(getContext(), i);
        call.resolve();
    }

    @PluginMethod
    public void playSound(PluginCall call) {
        JSObject d = call.getData();
        Sounds.useAlarm = d.optBoolean("alarm", Sounds.useAlarm);
        Sounds.play(getContext(), d.optString("name", "chime"));
        call.resolve();
    }

    /**
     * Salva um arquivo de backup em Downloads/MeuTreino pelo MediaStore (Android 10+),
     * que não precisa de permissão e mantém o arquivo mesmo se o app for desinstalado.
     * Mantém apenas os últimos "keep" arquivos automáticos (meutreino-auto-*).
     */
    @PluginMethod
    public void saveBackup(PluginCall call) {
        String name = call.getString("name", "meutreino-backup.json");
        String data = call.getString("data", "");
        int keep = call.getData().optInt("keep", 7);
        try {
            byte[] bytes = data.getBytes(StandardCharsets.UTF_8);
            if (Build.VERSION.SDK_INT >= 29) {
                ContentResolver cr = getContext().getContentResolver();
                Uri col = MediaStore.Downloads.EXTERNAL_CONTENT_URI;
                String rel = Environment.DIRECTORY_DOWNLOADS + "/MeuTreino/";
                Uri target = null;
                List<Uri> autos = new ArrayList<>();
                try (Cursor c = cr.query(col, new String[]{MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DISPLAY_NAME},
                        MediaStore.MediaColumns.RELATIVE_PATH + "=?", new String[]{rel}, MediaStore.MediaColumns.DISPLAY_NAME + " ASC")) {
                    if (c != null) while (c.moveToNext()) {
                        Uri u = ContentUris.withAppendedId(col, c.getLong(0));
                        String n = c.getString(1);
                        if (name.equals(n)) target = u;
                        else if (n != null && n.startsWith("meutreino-auto-")) autos.add(u);
                    }
                }
                if (target == null) {
                    ContentValues v = new ContentValues();
                    v.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
                    v.put(MediaStore.MediaColumns.MIME_TYPE, "application/json");
                    v.put(MediaStore.MediaColumns.RELATIVE_PATH, rel);
                    target = cr.insert(col, v);
                }
                if (target == null) throw new Exception("não foi possível criar o arquivo");
                try (OutputStream os = cr.openOutputStream(target, "wt")) {
                    if (os == null) throw new Exception("não foi possível abrir o arquivo");
                    os.write(bytes);
                }
                if (name.startsWith("meutreino-auto-")) {
                    int extra = autos.size() + 1 - keep;
                    for (int k = 0; k < extra && k < autos.size(); k++) {
                        try { cr.delete(autos.get(k), null, null); } catch (Exception ignored) { }
                    }
                }
            } else {
                File dir = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "MeuTreino");
                if (!dir.exists()) dir.mkdirs();
                try (FileOutputStream fo = new FileOutputStream(new File(dir, name))) { fo.write(bytes); }
            }
            JSObject r = new JSObject();
            r.put("path", "Downloads/MeuTreino/" + name);
            call.resolve(r);
        } catch (Exception e) {
            call.reject(e.getMessage() == null ? "erro ao salvar" : e.getMessage());
        }
    }

    @PluginMethod
    public void stop(PluginCall call) {
        Intent i = new Intent(getContext(), WorkoutService.class);
        getContext().stopService(i);
        call.resolve();
    }
}
