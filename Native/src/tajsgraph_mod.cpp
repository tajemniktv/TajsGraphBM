#include "tajsgraph_mod.hpp"

#include <DynamicOutput/DynamicOutput.hpp>
#include <UE4SSProgram.hpp>

#include <cstring>
#include <format>
#include <string>

using namespace RC;

namespace tajsgraph::native
{
const char* TajsGraphBMNativeMod::bool_to_token(bool value)
{
    return value ? "true" : "false";
}

void TajsGraphBMNativeMod::push_core_settings()
{
    // Keep key names aligned with Scripts/config.lua core_ui_keys.
    m_console.run_set("spotlight_tune_enabled", bool_to_token(m_state.spotlight_tune_enabled));
    m_console.run_set("spotlight_runtime_compat_enabled", bool_to_token(m_state.spotlight_runtime_compat_enabled));
    m_console.run_set("enable_megalights", bool_to_token(m_state.enable_megalights));
    m_console.run_set("force_lumen_methods", bool_to_token(m_state.force_lumen_methods));
    m_console.run_set("force_lumen_compatibility", bool_to_token(m_state.force_lumen_compatibility));

    m_console.run_set("spotlight_intensity_multiplier", std::format("{:.4f}", m_state.spotlight_intensity_multiplier));
    m_console.run_set("spotlight_attenuation_multiplier", std::format("{:.4f}", m_state.spotlight_attenuation_multiplier));
    m_console.run_set("megalights_shadow_method", std::to_string(m_state.megalights_shadow_method));
    m_console.run_set("lumen_scene_detail", std::format("{:.4f}", m_state.lumen_scene_detail));
    m_console.run_set("lumen_diffuse_color_boost", std::format("{:.4f}", m_state.lumen_diffuse_color_boost));
    m_console.run_set("lumen_skylight_leaking", std::format("{:.4f}", m_state.lumen_skylight_leaking));
}

void TajsGraphBMNativeMod::render_header()
{
    ImGui::Text("TajsGraphBM - UI MVP");
    ImGui::TextWrapped("This tab sends commands to the Lua runtime bridge: tajsgraph.ui.*");
    ImGui::Separator();
    ImGui::TextWrapped("UMG status: %s", m_umg.is_widget_active() ? "active" : "inactive");
    ImGui::TextWrapped("UMG result: %s", m_umg.last_result().c_str());
    ImGui::Separator();
}

void TajsGraphBMNativeMod::render_actions()
{
    if (ImGui::Button("Apply"))
    {
        push_core_settings();
        m_console.run_command("tajsgraph.ui.apply");
    }
    ImGui::SameLine();
    if (ImGui::Button("Rebaseline"))
    {
        m_console.run_command("tajsgraph.rebaseline");
    }
    ImGui::SameLine();
    if (ImGui::Button("Restore"))
    {
        m_console.run_command("tajsgraph.restore");
    }
    ImGui::SameLine();
    if (ImGui::Button("Disable"))
    {
        m_console.run_command("tajsgraph.disable");
    }

    if (ImGui::Button("Save"))
    {
        push_core_settings();
        m_console.run_command("tajsgraph.ui.save");
    }
    ImGui::SameLine();
    if (ImGui::Button("Reload"))
    {
        m_console.run_command("tajsgraph.ui.reload");
    }
    ImGui::SameLine();
    if (ImGui::Button("Reset Core"))
    {
        m_console.run_command("tajsgraph.ui.reset_core");
    }
    ImGui::SameLine();
    if (ImGui::Button("Status"))
    {
        m_console.run_command("tajsgraph.ui.status");
    }
    ImGui::SameLine();
    if (ImGui::Button("Toggle UMG"))
    {
        // Defer UObject interaction to on_update where we already run runtime work.
        m_toggle_umg_requested = true;
    }
    ImGui::SameLine();
    if (ImGui::Button("Spawn UMG"))
    {
        m_umg.set_widget_class_path(m_widget_class_path_buffer);
        m_umg.spawn_widget();
    }
    ImGui::SameLine();
    if (ImGui::Button("Close UMG"))
    {
        m_umg.remove_widget();
    }

    ImGui::Separator();
    const std::string last_result = m_console.last_result();
    ImGui::TextWrapped("Last result: %s", last_result.c_str());
    ImGui::InputText("WidgetClassPath", m_widget_class_path_buffer, sizeof(m_widget_class_path_buffer));
    ImGui::Separator();
}

void TajsGraphBMNativeMod::render_core_controls()
{
    ImGui::Text("Core Toggles");
    ImGui::Checkbox("Spotlight Tune Enabled", &m_state.spotlight_tune_enabled);
    ImGui::Checkbox("Spotlight Runtime Compat Enabled", &m_state.spotlight_runtime_compat_enabled);
    ImGui::Checkbox("Enable MegaLights", &m_state.enable_megalights);
    ImGui::Checkbox("Force Lumen Methods", &m_state.force_lumen_methods);
    ImGui::Checkbox("Force Lumen Compatibility", &m_state.force_lumen_compatibility);

    ImGui::Separator();
    ImGui::Text("Core Numeric Controls");

    ImGui::SliderFloat("Spotlight Intensity Multiplier", &m_state.spotlight_intensity_multiplier, 0.0f, 4.0f, "%.3f");
    ImGui::SliderFloat("Spotlight Attenuation Multiplier", &m_state.spotlight_attenuation_multiplier, 0.0f, 4.0f, "%.3f");
    ImGui::SliderInt("MegaLights Shadow Method", &m_state.megalights_shadow_method, 0, 2);
    ImGui::SliderFloat("Lumen Scene Detail", &m_state.lumen_scene_detail, 0.25f, 8.0f, "%.3f");
    ImGui::SliderFloat("Lumen Diffuse Color Boost", &m_state.lumen_diffuse_color_boost, 0.0f, 8.0f, "%.3f");
    ImGui::SliderFloat("Lumen Skylight Leaking", &m_state.lumen_skylight_leaking, 0.0f, 1.0f, "%.3f");

    if (ImGui::Button("Push Settings Only"))
    {
        push_core_settings();
    }
}

TajsGraphBMNativeMod::TajsGraphBMNativeMod() : CppUserModBase()
{
    ModName = STR("TajsGraphBMNative");
    ModVersion = STR("1.0.0");
    ModDescription = STR("Native ImGui UI bridge for TajsGraphBM runtime");
    ModAuthors = STR("TajsGraphBM contributors");

    const std::string default_widget_path = "/Game/UI/WBP_TajsGraphBM.WBP_TajsGraphBM_C";
    strncpy_s(m_widget_class_path_buffer, sizeof(m_widget_class_path_buffer), default_widget_path.c_str(), _TRUNCATE);
    m_umg.set_widget_class_path(m_widget_class_path_buffer);

    register_tab(STR("TajsGraphBM UI"), [](CppUserModBase* instance) {
        auto* mod = dynamic_cast<TajsGraphBMNativeMod*>(instance);
        if (mod == nullptr)
        {
            return;
        }

        UE4SS_ENABLE_IMGUI()
        mod->render_header();
        mod->render_actions();
        mod->render_core_controls();
    });

    Output::send<LogLevel::Verbose>(STR("[TajsGraphBMNative] loaded\n"));
}

TajsGraphBMNativeMod::~TajsGraphBMNativeMod()
{
    m_umg.remove_widget();
}

auto TajsGraphBMNativeMod::on_update() -> void
{
    // Process queued runtime commands every frame.
    m_console.pump();
    if (m_toggle_umg_requested)
    {
        m_toggle_umg_requested = false;
        m_umg.set_widget_class_path(m_widget_class_path_buffer);
        m_umg.toggle_widget();
    }
}

auto TajsGraphBMNativeMod::on_ui_init() -> void
{
    UE4SS_ENABLE_IMGUI()
}

auto TajsGraphBMNativeMod::on_unreal_init() -> void
{
    UE4SSProgram* program = &UE4SSProgram::get_program();
    program->register_keydown_event(Input::Key::F9, [] {
        Output::send<LogLevel::Verbose>(STR("[TajsGraphBMNative] F9 pressed. Open UE4SS GUI and select 'TajsGraphBM UI' tab.\n"));
    });
    program->register_keydown_event(Input::Key::F8, [this] {
        m_toggle_umg_requested = true;
        Output::send<LogLevel::Verbose>(STR("[TajsGraphBMNative] F8 pressed. Queued UMG toggle.\n"));
    });
}
} // namespace tajsgraph::native
