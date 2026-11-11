package br.adriano.meutreino;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(WorkoutNotifPlugin.class);
        super.onCreate(savedInstanceState);
    }
}
