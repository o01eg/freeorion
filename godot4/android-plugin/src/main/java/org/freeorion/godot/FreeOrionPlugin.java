package org.freeorion.godot;

import android.content.Context;
import android.content.Intent;
import android.util.Log;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.ArrayList;
import java.util.List;

/**
 * Minimal FreeOrion Android plugin.
 * <p>
 * Godot 4 GDExtensions are loaded with dlopen() and expose no JavaVM/activity
 * to the extension, so the FreeOrion client would otherwise call InitDirs()
 * with a null JavaVM/activity and crash. This plugin re-loads the very same
 * libfreeoriongodot.so through System.loadLibrary so the JVM can resolve our
 * JNI method, then feeds it the current Godot activity.
 */
public final class FreeOrionPlugin extends GodotPlugin {

    private static final String TAG = "FreeOrionPlugin";

    static {
        System.loadLibrary("freeoriongodot");
    }

    public FreeOrionPlugin(Godot godot) {
        super(godot);
        Activity activity = getActivity();
        if (activity != null) {
            setAndroidActivity(activity);
        }
    }

    @Override
    public String getPluginName() {
        return "FreeOrion";
    }

    /**
     * Expose the "quickstart" intent extra (set by the launcher shortcut) as a
     * command line flag so the FreeOrion client can pick it up through the
     * normal OptionsDB command line parsing path.
     */
    @Override
    public List<String> getCommandLineParams(List<String> params) {
        List<String> result = new ArrayList<>(params);
        Activity activity = getActivity();
        if (activity != null && activity.getIntent().getBooleanExtra("quickstart", false)) {
            result.add("--quickstart");
        }
        return result;
    }

    private static native void setAndroidContext(Context activity);

    /**
     * Start the FreeOrion server service in its own process.
     * Called from native GodotClientApp::StartServer().
     */
    @UsedByGodot
    public void startServer(String[] args) {
        Activity activity = getActivity();
        if (activity == null) {
            Log.w(TAG, "No activity available; cannot start server service");
            return;
        }
        Log.i(TAG, "Starting FreeOrionServerService");
        Intent intent = new Intent(activity, FreeOrionServerService.class);
        intent.putExtra("args", serverArgs);
        activity.startService(intent);
    }

    /**
     * Stop the FreeOrion server service.
     * Called from native GodotClientApp::FreeServer().
     */
    @UsedByGodot
    public void stopServer() {
        Activity activity = getActivity();
        if (activity == null) {
            Log.w(TAG, "No activity available; cannot stop server service");
            return;
        }
        Log.i(TAG, "Stopping FreeOrionServerService");
        activity.stopService(new Intent(activity, FreeOrionServerService.class));
    }
}
