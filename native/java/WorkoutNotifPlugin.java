package br.adriano.meutreino;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;

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
        st.kg = call.getDouble("kg", 0.0);
        st.reps = call.getInt("reps", 0);
        st.kgStep = call.getDouble("kgStep", 2.5);
        st.restSec = call.getInt("restSec", 0);
        st.finished = call.getBoolean("finished", false);
        st.sound = call.getBoolean("sound", true);
        Double restEnd = call.getDouble("restEnd", 0.0);
        st.restEnd = restEnd == null ? 0L : restEnd.longValue();
        Intent i = new Intent(getContext(), WorkoutService.class);
        i.setAction(WorkoutService.ACTION_REFRESH);
        ContextCompat.startForegroundService(getContext(), i);
        call.resolve();
    }

    @PluginMethod
    public void stop(PluginCall call) {
        Intent i = new Intent(getContext(), WorkoutService.class);
        getContext().stopService(i);
        call.resolve();
    }
}
