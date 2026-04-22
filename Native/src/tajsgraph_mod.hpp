#pragma once

#include <Mod/CppUserModBase.hpp>

#include "console_bridge.hpp"
#include "ui_state.hpp"
#include "umg_bridge.hpp"

namespace tajsgraph::native
{
/**
 * @brief Native UE4SS mod entry that renders the ImGui tab and bridges to Lua commands.
 */
class TajsGraphBMNativeMod final : public RC::CppUserModBase
{
public:
    /** @brief Construct and register the native UI tab. */
    TajsGraphBMNativeMod();
    /** @brief Shutdown cleanup (best-effort UMG removal). */
    ~TajsGraphBMNativeMod() override;

    /** @brief Per-frame tick used to pump command queue and deferred UMG toggles. */
    auto on_update() -> void override;
    /** @brief UI lifecycle callback where ImGui is enabled. */
    auto on_ui_init() -> void override;
    /** @brief Unreal lifecycle callback for hotkey registration. */
    auto on_unreal_init() -> void override;

private:
    /** @brief Convert boolean settings to the Lua console token format. */
    static const char* bool_to_token(bool value);

    /** @brief Push current `CoreUiState` values to the Lua runtime bridge. */
    void push_core_settings();
    /** @brief Render top-level informational/status text. */
    void render_header();
    /** @brief Render action button row(s) and shared command actions. */
    void render_actions();
    /** @brief Render core setting controls mirrored from Lua config keys. */
    void render_core_controls();

private:
    /** @brief Current UI-editable core settings. */
    CoreUiState m_state{};
    /** @brief Console command queue/dispatcher. */
    ConsoleBridge m_console{};
    /** @brief UMG spawn/remove helper. */
    UmgBridge m_umg{};
    /** @brief Deferred toggle flag consumed in `on_update()`. */
    bool m_toggle_umg_requested{false};
    /** @brief Editable class-path buffer for UMG widget spawning. */
    char m_widget_class_path_buffer[512]{};
};
} // namespace tajsgraph::native
