#pragma once

namespace tajsgraph::native
{
struct CoreUiState
{
    bool spotlight_tune_enabled{true};
    bool spotlight_runtime_compat_enabled{true};
    bool enable_megalights{true};
    bool force_lumen_methods{true};
    bool force_lumen_compatibility{true};

    float spotlight_intensity_multiplier{0.90f};
    float spotlight_attenuation_multiplier{0.80f};
    int megalights_shadow_method{0};
    float lumen_scene_detail{8.0f};
    float lumen_diffuse_color_boost{1.5f};
    float lumen_skylight_leaking{0.05f};
};
} // namespace tajsgraph::native
