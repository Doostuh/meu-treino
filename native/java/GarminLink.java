package br.adriano.meutreino;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;

import com.garmin.android.connectiq.ConnectIQ;
import com.garmin.android.connectiq.IQApp;
import com.garmin.android.connectiq.IQDevice;
import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/**
 * Conversa com o app Meu Treino no relógio Garmin pelo Garmin Connect (Connect IQ Mobile SDK).
 * O celular manda o estado do treino; o relógio manda as ações (série feita, RIR, descanso...).
 */
public class GarminLink {
    static final String APP_ID = "73ef4abd4afc428cb9b4df30cfd01c95";
    private static GarminLink inst;

    private final Context ctx;
    private final Handler main = new Handler(Looper.getMainLooper());
    private ConnectIQ ciq;
    private final IQApp app = new IQApp(APP_ID);
    private final List<IQDevice> devices = new ArrayList<>();
    private final Map<Long, String> devStatus = new HashMap<>();
    private boolean ready = false;
    private boolean initializing = false;
    private String error = "";
    private String lastSend = "";
    private long lastSendAt = 0;
    private long lastRecvAt = 0;
    private Object pending = null;
    private String lastJson = "";
    private boolean sending = false;

    static synchronized GarminLink get(Context c) {
        if (inst == null) inst = new GarminLink(c.getApplicationContext());
        return inst;
    }

    private GarminLink(Context c) { ctx = c; }

    void init() {
        if (ready || initializing) return;
        initializing = true;
        main.post(() -> {
            try {
                ciq = ConnectIQ.getInstance(ctx, ConnectIQ.IQConnectType.WIRELESS);
                ciq.initialize(ctx, false, new ConnectIQ.ConnectIQListener() {
                    @Override public void onSdkReady() {
                        ready = true; initializing = false; error = "";
                        refreshDevices();
                        flush();
                    }
                    @Override public void onInitializeError(ConnectIQ.IQSdkErrorStatus status) {
                        ready = false; initializing = false; error = String.valueOf(status);
                    }
                    @Override public void onSdkShutDown() {
                        ready = false; initializing = false;
                    }
                });
            } catch (Throwable t) {
                initializing = false; error = String.valueOf(t.getMessage());
            }
        });
    }

    void refreshDevices() {
        if (!ready || ciq == null) return;
        try {
            List<IQDevice> known = ciq.getKnownDevices();
            if (known == null) return;
            for (IQDevice d : known) {
                boolean have = false;
                for (IQDevice x : devices) if (x.getDeviceIdentifier() == d.getDeviceIdentifier()) have = true;
                if (have) continue;
                devices.add(d);
                try { devStatus.put(d.getDeviceIdentifier(), String.valueOf(ciq.getDeviceStatus(d))); } catch (Throwable ignored) { }
                try {
                    ciq.registerForDeviceEvents(d, (device, status) -> {
                        devStatus.put(device.getDeviceIdentifier(), String.valueOf(status));
                        if (status == IQDevice.IQDeviceStatus.CONNECTED) { lastJson = ""; flush(); }
                        emitStatus();
                    });
                } catch (Throwable ignored) { }
                try {
                    ciq.registerForAppEvents(d, app, (device, iqApp, messages, status) -> {
                        if (messages == null) return;
                        lastRecvAt = System.currentTimeMillis();
                        for (Object m : messages) {
                            Object j = toJson(m);
                            JSObject ev = new JSObject();
                            ev.put("type", "watch");
                            ev.put("m", j);
                            WorkoutNotifPlugin.emitWatch(ev);
                        }
                    });
                } catch (Throwable ignored) { }
            }
        } catch (Throwable t) {
            error = String.valueOf(t.getMessage());
        }
    }

    private boolean connected(IQDevice d) {
        String s = devStatus.get(d.getDeviceIdentifier());
        return s == null || "CONNECTED".equals(s);
    }

    /** Envia o estado (JSON) para o relógio. Mensagens repetidas são ignoradas. */
    void send(JSONObject msg) {
        if (msg == null) return;
        String js = msg.toString();
        pending = toJava(msg);
        if (js.equals(lastJson) && System.currentTimeMillis() - lastSendAt < 15000) { pending = null; return; }
        lastJson = js;
        if (!ready) { init(); return; }
        flush();
    }

    private void flush() {
        main.post(() -> {
            if (!ready || ciq == null || pending == null || sending) return;
            if (devices.isEmpty()) refreshDevices();
            final Object msg = pending;
            pending = null;
            lastSendAt = System.currentTimeMillis();
            for (IQDevice d : devices) {
                if (!connected(d)) continue;
                try {
                    sending = true;
                    ciq.sendMessage(d, app, msg, (device, iqApp, status) -> {
                        sending = false;
                        lastSend = String.valueOf(status);
                        if (pending != null) flush();
                    });
                } catch (Throwable t) {
                    sending = false;
                    lastSend = "ERRO: " + t.getMessage();
                }
            }
            // garante que não trava se nenhum callback vier
            main.postDelayed(() -> { if (sending && System.currentTimeMillis() - lastSendAt > 8000) { sending = false; flush(); } }, 9000);
        });
    }

    void openApp(final Runnable done) {
        main.post(() -> {
            if (!ready || ciq == null) { init(); if (done != null) done.run(); return; }
            if (devices.isEmpty()) refreshDevices();
            for (IQDevice d : devices) {
                if (!connected(d)) continue;
                try {
                    ciq.openApplication(d, app, (device, iqApp, status) -> lastSend = "ABRIR: " + status);
                } catch (Throwable t) {
                    lastSend = "ERRO ao abrir: " + t.getMessage();
                }
            }
            if (done != null) done.run();
        });
    }

    JSObject status() {
        JSObject o = new JSObject();
        o.put("ready", ready);
        o.put("error", error);
        o.put("lastSend", lastSend);
        o.put("lastSendAt", lastSendAt);
        o.put("lastRecvAt", lastRecvAt);
        JSArray arr = new JSArray();
        for (IQDevice d : devices) {
            JSObject x = new JSObject();
            x.put("name", d.getFriendlyName());
            String s = devStatus.get(d.getDeviceIdentifier());
            x.put("status", s == null ? "?" : s);
            arr.put(x);
        }
        o.put("devices", arr);
        return o;
    }

    private void emitStatus() {
        JSObject ev = new JSObject();
        ev.put("type", "watchStatus");
        ev.put("s", status());
        WorkoutNotifPlugin.emitWatch(ev);
    }

    // ---------- conversão JSON <-> objetos que o SDK aceita ----------
    static Object toJava(Object v) {
        if (v == null || v == JSONObject.NULL) return null;
        if (v instanceof JSONObject) {
            JSONObject o = (JSONObject) v;
            HashMap<String, Object> m = new HashMap<>();
            Iterator<String> it = o.keys();
            while (it.hasNext()) {
                String k = it.next();
                Object x = toJava(o.opt(k));
                if (x != null) m.put(k, x);
            }
            return m;
        }
        if (v instanceof JSONArray) {
            JSONArray a = (JSONArray) v;
            ArrayList<Object> l = new ArrayList<>();
            for (int i = 0; i < a.length(); i++) {
                Object x = toJava(a.opt(i));
                l.add(x == null ? "" : x);
            }
            return l;
        }
        if (v instanceof Number) {
            Number n = (Number) v;
            double d = n.doubleValue();
            if (d == Math.rint(d) && Math.abs(d) < 2e9) return Integer.valueOf((int) d);
            return Float.valueOf((float) d);
        }
        return v;
    }

    static Object toJson(Object v) {
        if (v == null) return JSONObject.NULL;
        if (v instanceof Map) {
            JSObject o = new JSObject();
            for (Object e : ((Map<?, ?>) v).entrySet()) {
                Map.Entry<?, ?> en = (Map.Entry<?, ?>) e;
                o.put(String.valueOf(en.getKey()), toJson(en.getValue()));
            }
            return o;
        }
        if (v instanceof List) {
            JSArray a = new JSArray();
            for (Object x : (List<?>) v) a.put(toJson(x));
            return a;
        }
        return v;
    }
}
