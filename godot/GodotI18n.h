#ifndef _GODOT_I18N_H_
#define _GODOT_I18N_H_

#include <Godot.hpp>
#include <Translation.hpp>

namespace godot {
    class GodotI18n : public Translation {
        GODOT_CLASS(GodotI18n, Translation)

    private:
        String m_locale;
    public:
        static void _register_methods();

        GodotI18n();
        ~GodotI18n();

        void _init(); // our initializer called by Godot

        void add_message(const String src_message, const String xlated_message);
        void erase_message(const String src_message);
        String get_message(const String src_message) const;
        int64_t get_message_count() const;
        PoolStringArray get_message_list() const;

        String get_locale() const;
        void set_locale(const String locale);
    };
}

#endif

