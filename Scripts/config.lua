local M = {
    __tajsgraph_module = "config"
}

M.defaults = {
    -- Spotlight tuning
    spotlight_tune_enabled = true,
    spotlight_tune_mode = "multiplier", -- "multiplier" or "absolute"

    spotlight_intensity = -1.0,
    spotlight_indirect_lighting_intensity = -1.0,
    spotlight_specular_scale = -1.0,
    spotlight_attenuation_radius = -1.0,
    spotlight_outer_cone_angle = -1.0,
    spotlight_inner_cone_angle = -1.0,
    spotlight_source_radius = -1.0,
    spotlight_soft_source_radius = -1.0,
    spotlight_source_length = -1.0,

    spotlight_intensity_multiplier = 1.0,
    spotlight_indirect_lighting_multiplier = 1.0,
    spotlight_specular_multiplier = 1.0,
    spotlight_attenuation_multiplier = 1.0,
    spotlight_outer_cone_multiplier = 1.0,
    spotlight_inner_cone_multiplier = 1.0,
    spotlight_source_radius_multiplier = 1.0,
    spotlight_soft_source_radius_multiplier = 1.0,
    spotlight_source_length_multiplier = 1.0,
    spotlight_force_runtime_compat = true,
    spotlight_force_movable = true,
    spotlight_force_mobility_value = 2,
    spotlight_force_cast_shadows = true,
    spotlight_force_visible_enabled = true,

    -- MegaLights + Lumen compatibility
    enable_megalights = true,
    force_lumen_methods = true,
    force_lumen_compatibility = true,

    megalights_shadow_method = 2,
    lumen_gi_method_value = 1,
    lumen_reflection_method_value = 1,
    lumen_scene_detail = 8.0,
    lumen_diffuse_color_boost = 1.5,
    lumen_skylight_leaking = 0.05,
    lumen_max_trace_distance = 200000,

    lumen_disable_static_lighting = true,
    lumen_force_no_precomputed_lighting = true,
    lumen_enable_mesh_distance_fields = true,
    lumen_disable_forward_shading = true,

    -- Runtime behavior
    auto_apply_on_startup = false,
    auto_apply_startup_followup = false,
    auto_apply_on_transition = false,
    auto_apply_on_spawn = false,
    auto_backup_loop = false,

    backup_tick_ms = 15000,
    backup_full_scan_every_ticks = 16,
    backup_render_every_ticks = 8,
    transition_apply_delay_ms = 750,
    startup_followup_delay_ms = 2500,

    diagnostic_logging = true,
    backup_diagnostic_every_ticks = 16,
}

local NUMERIC_KEYS = {
    "spotlight_intensity",
    "spotlight_indirect_lighting_intensity",
    "spotlight_specular_scale",
    "spotlight_attenuation_radius",
    "spotlight_outer_cone_angle",
    "spotlight_inner_cone_angle",
    "spotlight_source_radius",
    "spotlight_soft_source_radius",
    "spotlight_source_length",
    "spotlight_intensity_multiplier",
    "spotlight_indirect_lighting_multiplier",
    "spotlight_specular_multiplier",
    "spotlight_attenuation_multiplier",
    "spotlight_outer_cone_multiplier",
    "spotlight_inner_cone_multiplier",
    "spotlight_source_radius_multiplier",
    "spotlight_soft_source_radius_multiplier",
    "spotlight_source_length_multiplier",
    "spotlight_force_mobility_value",
    "megalights_shadow_method",
    "lumen_gi_method_value",
    "lumen_reflection_method_value",
    "lumen_scene_detail",
    "lumen_diffuse_color_boost",
    "lumen_skylight_leaking",
    "lumen_max_trace_distance",
    "backup_tick_ms",
    "backup_full_scan_every_ticks",
    "backup_render_every_ticks",
    "transition_apply_delay_ms",
    "startup_followup_delay_ms",
    "backup_diagnostic_every_ticks",
}

local BOOL_KEYS = {
    "spotlight_tune_enabled",
    "spotlight_force_runtime_compat",
    "spotlight_force_movable",
    "spotlight_force_cast_shadows",
    "spotlight_force_visible_enabled",
    "enable_megalights",
    "force_lumen_methods",
    "force_lumen_compatibility",
    "lumen_disable_static_lighting",
    "lumen_force_no_precomputed_lighting",
    "lumen_enable_mesh_distance_fields",
    "lumen_disable_forward_shading",
    "auto_apply_on_startup",
    "auto_apply_startup_followup",
    "auto_apply_on_transition",
    "auto_apply_on_spawn",
    "auto_backup_loop",
    "diagnostic_logging",
}

function M.normalize(config)
    if type(config) ~= "table" then
        config = {}
    end

    for key, value in pairs(M.defaults) do
        if config[key] == nil then
            config[key] = value
        end
    end

    if config.spotlight_tune_mode ~= "absolute" and config.spotlight_tune_mode ~= "multiplier" then
        config.spotlight_tune_mode = "multiplier"
    end

    for _, key in ipairs(NUMERIC_KEYS) do
        if type(config[key]) ~= "number" then
            config[key] = M.defaults[key]
        end
    end

    for _, key in ipairs(BOOL_KEYS) do
        config[key] = config[key] == true
    end

    config.backup_tick_ms = math.max(500, math.floor(config.backup_tick_ms))
    config.backup_full_scan_every_ticks = math.max(1, math.floor(config.backup_full_scan_every_ticks))
    config.backup_render_every_ticks = math.max(1, math.floor(config.backup_render_every_ticks))
    config.transition_apply_delay_ms = math.max(100, math.floor(config.transition_apply_delay_ms))
    config.startup_followup_delay_ms = math.max(250, math.floor(config.startup_followup_delay_ms))
    config.backup_diagnostic_every_ticks = math.max(1, math.floor(config.backup_diagnostic_every_ticks))
    config.spotlight_force_mobility_value = math.max(0, math.floor(config.spotlight_force_mobility_value))

    return config
end

return M
