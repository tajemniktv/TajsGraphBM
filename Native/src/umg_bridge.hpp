#pragma once

#include <string>

namespace RC::Unreal
{
class UObject;
}

namespace tajsgraph::native
{
/**
 * @brief Minimal runtime bridge for spawning/removing an in-game UMG widget.
 */
class UmgBridge
{
public:
    /** @brief Update the Widget Blueprint class object path used for spawning. */
    void set_widget_class_path(const std::string& path);
    /** @brief Return the current Widget Blueprint class path. */
    const std::string& widget_class_path() const;

    /**
     * @brief Spawn the configured widget and add it to viewport.
     * @return True when a widget is active after the call.
     */
    bool spawn_widget();
    /**
     * @brief Remove the active widget from parent.
     * @return True if an active widget was removed.
     */
    bool remove_widget();
    /**
     * @brief Toggle widget visibility by remove/spawn.
     * @return True if toggle operation succeeded.
     */
    bool toggle_widget();

    /** @brief Check whether a widget instance is currently active. */
    bool is_widget_active() const;
    /** @brief Retrieve the latest operation result string for UI/debug output. */
    const std::string& last_result() const;

private:
    /** @brief Find a usable world context object for UMG create calls. */
    static RC::Unreal::UObject* find_world_context();
    /** @brief Find the first available PlayerController as widget owner. */
    static RC::Unreal::UObject* find_player_controller();

private:
    /** @brief Soft object path to the widget class (`..._C`). */
    std::string m_widget_class_path{};
    /** @brief Active widget instance, or null when inactive. */
    RC::Unreal::UObject* m_widget_instance{};
    /** @brief Human-readable status for the native UI tab. */
    std::string m_last_result{"UMG idle"};
};
} // namespace tajsgraph::native
