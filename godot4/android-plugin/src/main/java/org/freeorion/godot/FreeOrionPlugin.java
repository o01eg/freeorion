package org.freeorion.godot;

import android.app.Activity;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;

/**
 * Minimal FreeOrion Android plugin.
 * <p>
 * Godot 4 GDExtensions are loaded with dlopen() and expose no JavaVM/activity
 * to the extension, so the FreeOrion client would otherwise call InitDirs()
 * with a null JavaVM/activity and crash. This plugin re-loads the very same
 * libfreeoriongodot.so through System.loadLibrary so the JVM can resolve our
 * JNI method (binds to Java_org_freeorion_godot_FreeOrionPlugin_nativeSetAndroidActivity
 * exported from that library), then feeds it the current Godot activity.
 */
public final class FreeOrionPlugin extends GodotPlugin {

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

    private static native void setAndroidActivity(Activity activity);
}
