#include "AndroidAIService.h"

#include "../util/AndroidEnvironment.h"

namespace {
    void ControlAndroidService(std::string class_name, bool start) {
        ScopedJNIEnv env;
        jobject context = env->NewLocalRef(ScopedJNIEnv::Context());
        jclass service_cls = env->FindClass(class_name.c_str());
        jclass intent_cls = env->FindClass("android/content/Intent");
        jmethodID intent_ctor_mid = env->GetMethodID(intent_cls, "<init>", "(Landroid/content/Context;Ljava/lang/Class;)V");
        jobject intent = env->NewObject(intent_cls, intent_ctor_mid, context, service_cls);
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

AndroidAIService::AndroidAIService(int slot_id)
    : m_slot_id(slot_id)
{ ControlAndroidService("org/freeorion/godot/FreeOrionAIService" + std::to_string(m_slot_id), true); }

AndroidAIService::~AndroidAIService()
{ ControlAndroidService("org/freeorion/godot/FreeOrionAIService" + std::to_string(m_slot_id), false); }
