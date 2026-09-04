package org.freeorion.godot;

import android.content.Context;
import android.app.Service;
import android.content.Intent;
import android.os.IBinder;
import android.os.Process;
import android.util.Log;

/**
 * Hosts the FreeOrion server in a dedicated Android process.
 *
 * Declared with {@code android:process=":server"} so the server's long event
 * loop and networking run in a separate process from the Godot UI and never
 * stall it. The dedicated process shares the application's assets, so it can
 * access {@code res://bin/libfreeoriond.so} and the game data bundled in the
 * APK.
 *
 * TODO: load libfreeoriond and run the server loop here.
 */
public final class FreeOrionServerService extends Service {
    private static final String TAG = "FreeOrionServerService";

    @Override
    public void onCreate() {
        super.onCreate();
        Log.i(TAG, "FreeOrion server service created (pid=" + Process.myPid() + ")");
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.i(TAG, "FreeOrion server service started; keeping it running");
        String[] serverArgs = null;
        if (intent != null) {
            serverArgs = intent.getStringArrayExtra("args");
        }

        final String[] finalArgs = serverArgs;
        System.loadLibrary("freeoriond");
        new Thread(() -> {
            startService(this, finalArgs);
        }, "FreeOrionServerThread").start();
        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onDestroy() {
        stopService();
        super.onDestroy();
        Log.i(TAG, "FreeOrion server service destroyed");
    }

    private static native int startService(Context activity, String[] args);
    private static native void stopService();
}
