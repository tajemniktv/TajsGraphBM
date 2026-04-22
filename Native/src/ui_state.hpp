#pragma once

namespace tajsgraph::native
{
/**
 * @brief Mirrors the Lua "core UI" settings exposed in the native ImGui tab.
 *
 * Values here are pushed into the Lua runtime through `tajsgraph.ui.set`.
 */
struct CoreUiState
{
    /** @brief Enables numeric spotlight tuning in the Lua runtime. */
    bool spotlight_tune_enabled{true};
    /** @brief Enables runtime spotlight compatibility writes (visibility/mobility). */
    bool spotlight_runtime_compat_enabled{true};
    /** @brief Enables MegaLights-related render settings. */
    bool enable_megalights{true};
    /** @brief Forces Lumen GI/reflection method selection. */
    bool force_lumen_methods{true};
    /** @brief Forces supplementary Lumen compatibility toggles. */
    bool force_lumen_compatibility{true};

    /** @brief Spotlight intensity multiplier in multiplier mode. */
    float spotlight_intensity_multiplier{0.90f};
    /** @brief Spotlight attenuation radius multiplier in multiplier mode. */
    float spotlight_attenuation_multiplier{0.80f};
    /** @brief Enum-like shadow method value (expected range: 0..2). */
    int megalights_shadow_method{0};
    /** @brief Lumen scene detail scalar (expected range: 0.25..8.0). */
    float lumen_scene_detail{8.0f};
    /** @brief Lumen diffuse color boost scalar. */
    float lumen_diffuse_color_boost{1.5f};
    /** @brief Lumen skylight leaking scalar. */
    float lumen_skylight_leaking{0.05f};
};
} // namespace tajsgraph::native
