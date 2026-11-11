package br.adriano.meutreino;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.os.Build;

/**
 * Toca os sons próprios do app (sino de fim de descanso, tique da contagem, início do timer).
 * Por padrão usa o canal de mídia: sai no fone por cima da música, que abaixa por um instante.
 * Com "alarm" usa o volume de alarme, que costuma ser mais alto.
 */
public class Sounds {
    static boolean useAlarm = false;

    static int resOf(String name) {
        switch (name) {
            case "tick": return R.raw.rest_tick;
            case "go": return R.raw.rest_go;
            default: return R.raw.rest_chime;
        }
    }

    static void play(Context ctx, String name) {
        try {
            final AudioManager am = (AudioManager) ctx.getSystemService(Context.AUDIO_SERVICE);
            AudioAttributes attrs = new AudioAttributes.Builder()
                    .setUsage(useAlarm ? AudioAttributes.USAGE_ALARM : AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build();
            final AudioFocusRequest[] req = new AudioFocusRequest[1];
            if (am != null && Build.VERSION.SDK_INT >= 26) {
                req[0] = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                        .setAudioAttributes(attrs).build();
                am.requestAudioFocus(req[0]);
            }
            MediaPlayer mp = new MediaPlayer();
            mp.setAudioAttributes(attrs);
            mp.setDataSource(ctx, android.net.Uri.parse("android.resource://" + ctx.getPackageName() + "/" + resOf(name)));
            mp.setVolume(1f, 1f);
            mp.setOnCompletionListener(p -> {
                p.release();
                if (am != null && Build.VERSION.SDK_INT >= 26 && req[0] != null) am.abandonAudioFocusRequest(req[0]);
            });
            mp.setOnErrorListener((p, w, e) -> { p.release(); return true; });
            mp.prepare();
            mp.start();
        } catch (Exception ignored) { }
    }
}
