#pragma once

#include <Mod/CppUserModBase.hpp>

#include "console_bridge.hpp"
#include "ui_state.hpp"

namespace tajsgraph::native
{
class TajsGraphBMNativeMod final : public RC::CppUserModBase
{
public:
    TajsGraphBMNativeMod();
    ~TajsGraphBMNativeMod() override;

    auto on_ui_init() -> void override;
    auto on_unreal_init() -> void override;

private:
    static const char* bool_to_token(bool value);

    void push_core_settings();
    void render_header();
    void render_actions();
    void render_core_controls();

private:
    CoreUiState m_state{};
    ConsoleBridge m_console{};
};
} // namespace tajsgraph::native
