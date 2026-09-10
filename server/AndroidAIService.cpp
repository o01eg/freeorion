#include "AndroidAIService.h"

#include "../util/AndroidEnvironment.h"

namespace {
    void ControlAndroidService(const std::string& class_name, bool start, const std::string& player_name = "") {
        ScopedJNIEnv env;
        jobject context = env->NewLocalRef(ScopedJNIEnv::Context());
        jclass service_cls = env->FindClass(class_name.c_str());
        jclass intent_cls = env->FindClass("android/content/Intent");
        jmethodID intent_ctor_mid = env->GetMethodID(intent_cls, "<init>", "(Landroid/content/Context;Ljava/lang/Class;)V");
        jobject intent = env->NewObject(intent_cls, intent_ctor_mid, context, service_cls);

        if (!player_name.empty()) {
            jmethodID put_extra_mid = env->GetMethodID(intent_cls, "putExtra", "(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;");
            jstring key = env->NewStringUTF("player_name");
            jstring value = env->NewStringUTF(player_name.c_str());
            env->CallObjectMethod(intent, put_extra_mid, key, value);
            env->DeleteLocalRef(key);
            env->DeleteLocalRef(value);
        }

        jclass context_cls = env->GetObjectClass(context);
        if (start) {
            jmethodID start_service_mid = env->GetMethodID(context_cls, "startService", "(Landroid/content/Intent;)Landroid/content/ComponentName;");
            env->CallObjectMethod(context, start_service_mid, intent);
        } else {
            jmethodID stop_service_mid = env->GetMethodID(context_cls, "stopService", "(Landroid/content/Intent;)Z");
            env->CallBooleanMethod(context, stop_service_mid, intent);
        }

        env->DeleteLocalRef(intent);
    }
}

AndroidAIService::AndroidAIService(int slot_id, const std::string& player_name)
    : m_slot_id(slot_id)
{ ControlAndroidService("org/freeorion/godot/FreeOrionAIService" + std::to_string(m_slot_id), true, player_name); }

AndroidAIService::~AndroidAIService()
{ Kill(); }

void AndroidAIService::Kill() {
    if (!m_killed) {
        ControlAndroidService("org/freeorion/godot/FreeOrionAIService" + std::to_string(m_slot_id), false);
        m_killed = true;
    }
}
