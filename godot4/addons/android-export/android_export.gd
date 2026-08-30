@tool
extends EditorPlugin

var export_plugin: AndroidExportPlugin

class AndroidExportPlugin extends EditorExportPlugin:
    func _get_name() -> String:
        return "AndroidExportPlugin"

    func _get_android_manifest_activity_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
        return '''
        <meta-data android:name="android.app.shortcuts" android:resource="@xml/shortcuts"/>
        '''

func _enter_tree() -> void:
    export_plugin = AndroidExportPlugin.new()
    add_export_plugin(export_plugin)

func _exit_tree() -> void:
    remove_export_plugin(export_plugin)
    export_plugin = null
