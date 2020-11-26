#include "GodotI18n.h"

#include <codecvt>

#include "../util/i18n.h"

using namespace godot;

void GodotI18n::_register_methods() {
    register_property<GodotI18n, String>("locale",
        &GodotI18n::set_locale,
        &GodotI18n::get_locale,
        "");
    register_method("add_message", &GodotI18n::add_message);
    register_method("erase_message", &GodotI18n::erase_message);
    register_method("get_message", &GodotI18n::get_message);
    register_method("get_message_count", &GodotI18n::get_message_count);
    register_method("get_message_list", &GodotI18n::get_message_list);
}

GodotI18n::GodotI18n()
{}

GodotI18n::~GodotI18n()
{}

void GodotI18n::_init()
{}

void GodotI18n::add_message(const String src_message, const String xlated_message) {
    // ignore it
    Godot::print(String("Ignore adding message"));
}

void GodotI18n::erase_message(const String src_message) {
    // ignore it
    Godot::print(String("Ignore erasing message"));
}

String GodotI18n::get_message(const String src_message) const {
    std::string src_message8 = std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>, wchar_t>{}.to_bytes(src_message.unicode_str());
    return String(UserString(src_message8).c_str());
}

int64_t GodotI18n::get_message_count() const {
    // ignore it
    Godot::print(String("Ignore getting message count"));
    return 0;
}

PoolStringArray GodotI18n::get_message_list() const {
    // ignore it
    Godot::print(String("Ignore getting message list"));
    return PoolStringArray();
}

String GodotI18n::get_locale() const
{ return m_locale; }

void GodotI18n::set_locale(const String locale)
{ m_locale = locale; }

