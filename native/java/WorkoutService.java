package br.adriano.meutreino;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.SystemClock;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.view.View;
import android.widget.RemoteViews;

import androidx.core.app.NotificationCompat;

import com.getcapacitor.JSObject;

import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.util.Locale;

/**
 * Serviço em primeiro plano que mantém a notificação do treino visível na tela de bloqueio.
 * Os botões da notificação chamam este serviço diretamente (sem abrir o app), por isso
 * funcionam sem desbloquear o celular na maioria dos aparelhos.
 */
public class WorkoutService extends Service {

    static final String CHANNEL = "treino_ativo";
    static final String CHANNEL_ALERT = "treino_descanso";
    static final int NOTIF_ID = 4712;
    static final String ACTION_REFRESH = "br.adriano.meutreino.REFRESH";
    static final String ACTION_KG_MINUS = "br.adriano.meutreino.KG_MINUS";
    static final String ACTION_KG_PLUS = "br.adriano.meutreino.KG_PLUS";
    static final String ACTION_REP_MINUS = "br.adriano.meutreino.REP_MINUS";
    static final String ACTION_REP_PLUS = "br.adriano.meutreino.REP_PLUS";
    static final String ACTION_DONE = "br.adriano.meutreino.DONE";
    static final String ACTION_ADD15 = "br.adriano.meutreino.ADD15";
    static final String ACTION_SKIP = "br.adriano.meutreino.SKIP";
    static final String ACTION_RIR = "br.adriano.meutreino.RIR";

    static class State {
        String title = "Treino", exercise = "", setLabel = "", next = "", key = "";
        double kg = 0, kgStep = 2.5;
        int reps = 0, restSec = 0;
        long restEnd = 0;
        boolean finished = false, sound = true;
        String rirKey = "", rirLabel = "";
        int rir = -1;
    }

    static final State STATE = new State();

    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Runnable restDone = this::onRestDone;
    private final Runnable tick = () -> { if (STATE.sound) Sounds.play(getApplicationContext(), "tick"); buzz(new long[]{0, 30}); };

    @Override
    public IBinder onBind(Intent intent) { return null; }

    @Override
    public void onCreate() {
        super.onCreate();
        createChannels();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String a = intent != null && intent.getAction() != null ? intent.getAction() : ACTION_REFRESH;
        State s = STATE;
        switch (a) {
            case ACTION_KG_MINUS: s.kg = Math.max(0, Math.round((s.kg - s.kgStep) * 100) / 100.0); emitVals(); break;
            case ACTION_KG_PLUS: s.kg = Math.round((s.kg + s.kgStep) * 100) / 100.0; emitVals(); break;
            case ACTION_REP_MINUS: s.reps = Math.max(0, s.reps - 1); emitVals(); break;
            case ACTION_REP_PLUS: s.reps = s.reps + 1; emitVals(); break;
            case ACTION_DONE: {
                if (s.finished || s.key.isEmpty()) break;
                if (s.restSec > 0) s.restEnd = System.currentTimeMillis() + s.restSec * 1000L;
                JSObject d = new JSObject();
                d.put("type", "done");
                d.put("key", s.key);
                d.put("kg", s.kg);
                d.put("reps", s.reps);
                d.put("restEnd", s.restEnd);
                WorkoutNotifPlugin.emit(d);
                buzz(new long[]{0, 40});
                break;
            }
            case ACTION_ADD15: {
                if (s.restEnd > System.currentTimeMillis()) s.restEnd += 15000;
                JSObject d = new JSObject(); d.put("type", "rest"); d.put("restEnd", s.restEnd); WorkoutNotifPlugin.emit(d);
                break;
            }
            case ACTION_SKIP: {
                s.restEnd = 0;
                JSObject d = new JSObject(); d.put("type", "rest"); d.put("restEnd", 0); WorkoutNotifPlugin.emit(d);
                break;
            }
            default:
                if (a.startsWith(ACTION_RIR) && !s.rirKey.isEmpty()) {
                    int v = Integer.parseInt(a.substring(ACTION_RIR.length() + 1));
                    s.rir = v;
                    JSObject d = new JSObject(); d.put("type", "rir"); d.put("key", s.rirKey); d.put("v", v);
                    WorkoutNotifPlugin.emit(d);
                    buzz(new long[]{0, 25});
                }
                break;
        }
        scheduleRest();
        Notification n = build();
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        } else {
            startForeground(NOTIF_ID, n);
        }
        return START_NOT_STICKY;
    }

    @Override
    public void onDestroy() {
        handler.removeCallbacks(restDone);
        handler.removeCallbacks(tick);
        super.onDestroy();
    }

    private void scheduleRest() {
        handler.removeCallbacks(restDone);
        handler.removeCallbacks(tick);
        long left = STATE.restEnd - System.currentTimeMillis();
        if (STATE.restEnd > 0 && left > 0) {
            handler.postDelayed(restDone, left);
            // contagem 3, 2, 1 antes do fim
            for (int k = 3; k >= 1; k--) {
                long at = left - k * 1000L;
                if (at > 0) handler.postDelayed(tick, at);
            }
        }
    }

    private void onRestDone() {
        STATE.restEnd = 0;
        buzz(new long[]{0, 280, 140, 280, 140, 420});
        if (STATE.sound) Sounds.play(getApplicationContext(), "chime");
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        // Alerta curto e visível (heads-up) avisando o fim do descanso
        NotificationCompat.Builder b = new NotificationCompat.Builder(this, CHANNEL_ALERT)
                .setSmallIcon(R.drawable.ic_stat_treino)
                .setContentTitle("Descanso encerrado")
                .setContentText(STATE.exercise + " • " + STATE.setLabel)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setTimeoutAfter(8000)
                .setAutoCancel(true);
        nm.notify(NOTIF_ID + 1, b.build());
        nm.notify(NOTIF_ID, build());
        JSObject d = new JSObject(); d.put("type", "restEnded"); WorkoutNotifPlugin.emit(d);
    }

    private void emitVals() {
        JSObject d = new JSObject(); d.put("type", "vals"); d.put("key", STATE.key); d.put("kg", STATE.kg); d.put("reps", STATE.reps);
        WorkoutNotifPlugin.emit(d);
    }

    private void buzz(long[] pattern) {
        try {
            Vibrator v = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
            if (v == null) return;
            if (Build.VERSION.SDK_INT >= 26) v.vibrate(VibrationEffect.createWaveform(pattern, -1));
            else v.vibrate(pattern, -1);
        } catch (Exception ignored) { }
    }

    private PendingIntent pi(String action, int code) {
        Intent i = new Intent(this, WorkoutService.class);
        i.setAction(action);
        int f = PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE;
        if (Build.VERSION.SDK_INT >= 26) return PendingIntent.getForegroundService(this, code, i, f);
        return PendingIntent.getService(this, code, i, f);
    }

    private static String fmtKg(double v) {
        DecimalFormat df = new DecimalFormat("0.##", DecimalFormatSymbols.getInstance(new Locale("pt", "BR")));
        return df.format(v);
    }

    private Notification build() {
        State s = STATE;
        boolean resting = s.restEnd > System.currentTimeMillis();
        String pkg = getPackageName();

        RemoteViews big = new RemoteViews(pkg, R.layout.notif_workout);
        RemoteViews small = new RemoteViews(pkg, R.layout.notif_workout_small);

        String ex = s.finished ? "Todas as séries concluídas" : s.exercise;
        String sub = s.finished ? "Abra o app para concluir o treino" : s.setLabel;
        big.setTextViewText(R.id.n_ex, ex);
        big.setTextViewText(R.id.n_sub, sub);
        big.setTextViewText(R.id.n_kg, fmtKg(s.kg) + " kg");
        big.setTextViewText(R.id.n_reps, s.reps + " reps");
        big.setTextViewText(R.id.n_next, s.next.isEmpty() ? "" : "Depois: " + s.next);
        big.setViewVisibility(R.id.n_next, s.next.isEmpty() ? View.GONE : View.VISIBLE);
        small.setTextViewText(R.id.s_ex, ex);
        small.setTextViewText(R.id.s_val, s.finished ? sub : fmtKg(s.kg) + " kg × " + s.reps + " • " + s.setLabel);

        int ctrlVis = s.finished ? View.GONE : View.VISIBLE;
        big.setViewVisibility(R.id.n_ctrl, ctrlVis);
        big.setViewVisibility(R.id.n_done, ctrlVis);
        small.setViewVisibility(R.id.s_done, ctrlVis);

        if (resting) {
            long base = SystemClock.elapsedRealtime() + (s.restEnd - System.currentTimeMillis());
            big.setViewVisibility(R.id.n_rest, View.VISIBLE);
            big.setChronometer(R.id.n_chrono, base, null, true);
            if (Build.VERSION.SDK_INT >= 24) big.setChronometerCountDown(R.id.n_chrono, true);
            small.setViewVisibility(R.id.s_chrono, View.VISIBLE);
            small.setChronometer(R.id.s_chrono, base, null, true);
            if (Build.VERSION.SDK_INT >= 24) small.setChronometerCountDown(R.id.s_chrono, true);
        } else {
            big.setViewVisibility(R.id.n_rest, View.GONE);
            small.setViewVisibility(R.id.s_chrono, View.GONE);
        }

        boolean showRir = !s.rirKey.isEmpty();
        big.setViewVisibility(R.id.n_rirbox, showRir ? View.VISIBLE : View.GONE);
        if (showRir) {
            big.setTextViewText(R.id.n_rirlbl, s.rirLabel.isEmpty() ? "Repetições na reserva (RIR)" : s.rirLabel);
            int[] ids = {R.id.n_rir0, R.id.n_rir1, R.id.n_rir2, R.id.n_rir3, R.id.n_rir4};
            for (int k = 0; k < 5; k++) {
                big.setInt(ids[k], "setBackgroundResource", s.rir == k ? R.drawable.notif_btn_on : R.drawable.notif_btn);
                big.setOnClickPendingIntent(ids[k], pi(ACTION_RIR + "_" + k, 20 + k));
            }
            big.setViewVisibility(R.id.n_next, View.GONE);
        }
        big.setOnClickPendingIntent(R.id.n_kg_minus, pi(ACTION_KG_MINUS, 1));
        big.setOnClickPendingIntent(R.id.n_kg_plus, pi(ACTION_KG_PLUS, 2));
        big.setOnClickPendingIntent(R.id.n_rep_minus, pi(ACTION_REP_MINUS, 3));
        big.setOnClickPendingIntent(R.id.n_rep_plus, pi(ACTION_REP_PLUS, 4));
        big.setOnClickPendingIntent(R.id.n_done, pi(ACTION_DONE, 5));
        big.setOnClickPendingIntent(R.id.n_add15, pi(ACTION_ADD15, 6));
        big.setOnClickPendingIntent(R.id.n_skip, pi(ACTION_SKIP, 7));
        small.setOnClickPendingIntent(R.id.s_done, pi(ACTION_DONE, 8));

        Intent open = getPackageManager().getLaunchIntentForPackage(pkg);
        PendingIntent openPi = open == null ? null :
                PendingIntent.getActivity(this, 9, open, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        NotificationCompat.Builder b = new NotificationCompat.Builder(this, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_treino)
                .setContentTitle(s.title)
                .setContentText(ex)
                .setCustomContentView(small)
                .setCustomBigContentView(big)
                .setStyle(new NotificationCompat.DecoratedCustomViewStyle())
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setSilent(true)
                .setShowWhen(false)
                .setCategory(NotificationCompat.CATEGORY_WORKOUT)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setPriority(NotificationCompat.PRIORITY_HIGH);
        if (openPi != null) b.setContentIntent(openPi);
        if (Build.VERSION.SDK_INT >= 31) b.setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE);
        return b.build();
    }

    private void createChannels() {
        if (Build.VERSION.SDK_INT < 26) return;
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        NotificationChannel c = new NotificationChannel(CHANNEL, "Treino em andamento", NotificationManager.IMPORTANCE_HIGH);
        c.setDescription("Controles do treino na tela de bloqueio");
        c.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
        c.setSound(null, null);
        c.enableVibration(false);
        c.setShowBadge(false);
        nm.createNotificationChannel(c);
        NotificationChannel a = new NotificationChannel(CHANNEL_ALERT, "Fim do descanso", NotificationManager.IMPORTANCE_HIGH);
        a.setDescription("Aviso quando o descanso termina");
        a.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
        a.setSound(null, null);
        a.enableVibration(false);
        nm.createNotificationChannel(a);
    }
}
