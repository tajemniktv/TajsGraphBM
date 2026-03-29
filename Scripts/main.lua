local MOD_TAG = "[TajsGraphBM]"

local UEHelpers = UEHelpers
if type(UEHelpers) ~= "table" and type(require) == "function" then
    local ok_helpers, loaded_helpers = pcall(require, "UEHelpers")
    if ok_helpers and type(loaded_helpers) == "table" then
        UEHelpers = loaded_helpers
    end
end

local tg_config = nil
if type(require) == "function" then
    local ok_cfg, loaded_cfg = pcall(require, "tg_config")
    if ok_cfg and type(loaded_cfg) == "table" and type(loaded_cfg.CONFIG) == "table" then
        tg_config = loaded_cfg
    end
end
if not tg_config then
    error("failed to load module 'tg_config'")
end
local CONFIG = tg_config.CONFIG
local tg_state = nil
if type(require) == "function" then
    local ok_state, loaded_state = pcall(require, "tg_state")
    if ok_state and type(loaded_state) == "table" and type(loaded_state.STATE) == "table" then
        tg_state = loaded_state
    end
end
if not tg_state then
    error("failed to load module 'tg_state'")
end
local STATE = tg_state.STATE

local normalize_config

local utils = nil
if type(require) == "function" then
    local ok_utils, loaded_utils = pcall(require, "tg_utils")
    if ok_utils and type(loaded_utils) == "table" then
        utils = loaded_utils
    end
end
if not utils then
    error("failed to load module 'tg_utils'")
end

local log = utils.log
local is_valid = utils.is_valid
local get_field = utils.get_field
local get_object_property = utils.get_object_property
local set_field = utils.set_field
local call_method_if_valid = utils.call_method_if_valid
local set_numeric_property = utils.set_numeric_property
local set_bool_property_confirmed = utils.set_bool_property_confirmed
local set_number_property_confirmed = utils.set_number_property_confirmed
local set_bool_property_multi = utils.set_bool_property_multi
local safe_inc_reason = utils.safe_inc_reason
local get_time_ms = utils.get_time_ms

local tg_autocomplete = nil
local run_autocomplete_status, run_autocomplete_probe, run_autocomplete_apply, run_autocomplete_reload, run_autocomplete_suggest, export_autocomplete_to_input_ini
local trim, normalize_dump_path
if type(require) == "function" then
    local ok_ac, ac = pcall(require, "tg_autocomplete")
    if ok_ac and type(ac) == "table" then
        tg_autocomplete = ac
    end
end
if tg_autocomplete then
    tg_autocomplete.set_logger(log)
    run_autocomplete_status = tg_autocomplete.run_autocomplete_status
    run_autocomplete_probe = tg_autocomplete.run_autocomplete_probe
    run_autocomplete_apply = tg_autocomplete.run_autocomplete_apply
    run_autocomplete_reload = tg_autocomplete.run_autocomplete_reload
    run_autocomplete_suggest = tg_autocomplete.run_autocomplete_suggest
    export_autocomplete_to_input_ini = tg_autocomplete.export_autocomplete_to_input_ini
    trim = tg_autocomplete.trim
    normalize_dump_path = tg_autocomplete.normalize_dump_path
end

-- Load lights module and override local light functions with module implementations
local tg_lights = nil
if type(require) == "function" then
    local ok_lights, loaded_lights = pcall(require, "tg_lights")
    if ok_lights and type(loaded_lights) == "table" then
        tg_lights = loaded_lights
    end
end
if tg_lights then
    get_light_key = tg_lights.get_light_key
    get_target_light_classes = tg_lights.get_target_light_classes
    set_light_shadow = tg_lights.set_light_shadow
    get_entry_light_kind = tg_lights.get_entry_light_kind
    enable_light_component = tg_lights.enable_light_component
    should_entry_cast_shadows = tg_lights.should_entry_cast_shadows
    tune_spotlight = tg_lights.tune_spotlight
    enforce_light_megalights = tg_lights.enforce_light_megalights
    capture_spotlight_prepatch = tg_lights.capture_spotlight_prepatch
    reset_spotlight_baselines = tg_lights.reset_spotlight_baselines
    patch_light_entry = tg_lights.patch_light_entry
    count_patched_total = tg_lights.count_patched_total
    refresh_light_cache = tg_lights.refresh_light_cache
    patch_cached_lights = tg_lights.patch_cached_lights
    refresh_shadow_slots = tg_lights.refresh_shadow_slots
    set_renderer_megalights = tg_lights.set_renderer_megalights
    apply_world_lumen_compatibility = tg_lights.apply_world_lumen_compatibility
    apply_ppv_settings = tg_lights.apply_ppv_settings
    set_postprocess_megalights = tg_lights.set_postprocess_megalights
    run_console_command = tg_lights.run_console_command
end

-- fog logic moved to tg_fog.lua

local tg_fog = nil
if type(require) == "function" then
    local ok_fog, loaded_fog = pcall(require, "tg_fog")
    if ok_fog and type(loaded_fog) == "table" then
        tg_fog = loaded_fog
    end
end
if tg_fog then
    collect_fog_targets = tg_fog.collect_fog_targets
    maybe_patch_fog = tg_fog.maybe_patch_fog
end


-- Load mesh module and override local mesh functions with module implementations
local tg_mesh = nil
if type(require) == "function" then
    local ok_mesh, loaded_mesh = pcall(require, "tg_mesh")
    if ok_mesh and type(loaded_mesh) == "table" then
        tg_mesh = loaded_mesh
    end
end
if tg_mesh then
    get_target_mesh_component_classes = tg_mesh.get_target_mesh_component_classes
    normalize_axis_name = tg_mesh.normalize_axis_name
    try_apply_pseudo_thickness = tg_mesh.try_apply_pseudo_thickness
    contains_any_name_filter = tg_mesh.contains_any_name_filter
    matches_filter_with_basename = tg_mesh.matches_filter_with_basename
    contains_any_scope_include = tg_mesh.contains_any_scope_include
    matches_any_scope_exclude = tg_mesh.matches_any_scope_exclude
    get_mesh_candidate_rejection_reason = tg_mesh.get_mesh_candidate_rejection_reason
    is_mesh_component_candidate = tg_mesh.is_mesh_component_candidate
    refresh_mesh_cache = tg_mesh.refresh_mesh_cache
    count_mesh_patched_total = tg_mesh.count_mesh_patched_total
    patch_mesh_entry = tg_mesh.patch_mesh_entry
    patch_cached_mesh_components = tg_mesh.patch_cached_mesh_components
    parse_mesh_find_request = tg_mesh.parse_mesh_find_request
    parse_filter_tokens = tg_mesh.parse_filter_tokens
    run_mesh_find = tg_mesh.run_mesh_find
    set_mesh_filters = tg_mesh.set_mesh_filters
    set_mesh_scope_include_filters = tg_mesh.set_mesh_scope_include_filters
    set_mesh_scope_exclude_filters = tg_mesh.set_mesh_scope_exclude_filters
    try_fix_wall_materials = tg_mesh.try_fix_wall_materials
    try_force_material = tg_mesh.try_force_material
end

-- Load skylight module and override local skylight functions with module implementations
local tg_skylight = nil
if type(require) == "function" then
    local ok_skylight, loaded_skylight = pcall(require, "tg_skylight")
    if ok_skylight and type(loaded_skylight) == "table" then
        tg_skylight = loaded_skylight
    end
end
if tg_skylight then
    collect_skylight_components = tg_skylight.collect_skylight_components
    maybe_patch_skylights = tg_skylight.maybe_patch_skylights
end

local function reset_runtime_diag_counters()
    STATE.skylight_found = 0
    STATE.skylight_valid = 0
    STATE.skylight_patched = 0
    STATE.skylight_movable_forced = 0
    STATE.skylight_realtime_enabled = 0
    STATE.skylight_recapture_attempted = 0
    STATE.skylight_recapture_ok = 0
    STATE.skylight_intensity_scaled = 0
    STATE.skylight_indirect_scaled = 0
    STATE.skylight_write_fail = 0

    STATE.fog_actors_found = 0
    STATE.fog_valid = 0
    STATE.fog_enabled = 0
    STATE.fog_volumetric_enabled = 0
    STATE.fog_lumen_fields_seen = 0
    STATE.fog_write_fail = 0

    STATE.df_component_scan_count = 0
    STATE.df_components_with_df_flags = 0
    STATE.df_verify_skipped_reason = ""

    STATE.mesh_components_found = 0
    STATE.mesh_components_candidates = 0
    STATE.mesh_foliage_components_found = 0
    STATE.mesh_foliage_components_candidates = 0
    STATE.mesh_skeletal_components_found = 0
    STATE.mesh_skeletal_components_candidates = 0
    STATE.mesh_ism_components_found = 0
    STATE.mesh_ism_components_candidates = 0
    STATE.mesh_hism_components_found = 0
    STATE.mesh_hism_components_candidates = 0
    STATE.mesh_components_patched_last = 0
    STATE.mesh_write_fail_last = 0
    STATE.mesh_filter_skipped_last = 0
    STATE.mesh_scope_skipped_last = 0
    STATE.mesh_force_apply_ops_last = 0
    STATE.mesh_lumen_cache_invalidations_last = 0
    STATE.mesh_lumen_cache_invalidation_fail_last = 0
    STATE.mesh_render_state_dirty_last = 0
    STATE.mesh_render_state_dirty_fail_last = 0
    STATE.mesh_cull_distance_ops_last = 0
    STATE.mesh_cull_distance_fail_last = 0
    STATE.mesh_bounds_scale_ops_last = 0
    STATE.mesh_bounds_scale_fail_last = 0
    STATE.mesh_pseudo_thickness_ops_last = 0
    STATE.mesh_pseudo_thickness_fail_last = 0
end

local function get_objects_of_class(class_name)
    if type(FindAllOf) ~= "function" then
        return {}
    end

    local ok, objects = pcall(FindAllOf, class_name)
    if ok and type(objects) == "table" then
        return objects
    end

    return {}
end

local function get_light_key(light_comp)
    local key_ok, key = pcall(function()
        return light_comp:GetFullName()
    end)

    if key_ok and type(key) == "string" and key ~= "" then
        return key
    end

    return tostring(light_comp)
end

local function get_component_class_name(comp, fallback_class_name)
    local class_name = tostring(fallback_class_name or "")

    if not is_valid(comp) then
        return class_name
    end

    local ok_class, class_obj = pcall(function()
        return comp:GetClass()
    end)
    if ok_class and is_valid(class_obj) then
        local ok_full, class_full_name = pcall(function()
            return class_obj:GetFullName()
        end)
        if ok_full and type(class_full_name) == "string" and class_full_name ~= "" then
            local dot_name = string.match(class_full_name, "%.([%w_]+)$")
            if dot_name ~= nil and dot_name ~= "" then
                class_name = dot_name
            end
        end

        if class_name == "" then
            local ok_name, class_short_name = pcall(function()
                return class_obj:GetName()
            end)
            if ok_name and type(class_short_name) == "string" and class_short_name ~= "" then
                class_name = class_short_name
            end
        end
    end

    if class_name == "" then
        local ok_comp_name, comp_full_name = pcall(function()
            return comp:GetFullName()
        end)
        if ok_comp_name and type(comp_full_name) == "string" and comp_full_name ~= "" then
            local head = string.match(comp_full_name, "^(%S+)%s")
            if head ~= nil and head ~= "" then
                class_name = head
            end
        end
    end

    return class_name
end

local function is_black_material_object(material_obj)
    if not is_valid(material_obj) then
        return false
    end

    local ok_name, full_name = pcall(function()
        return material_obj:GetFullName()
    end)
    if ok_name and type(full_name) == "string" then
        local lowered = string.lower(full_name)
        if string.find(lowered, "mi_black", 1, true) ~= nil or string.find(lowered, "m_black", 1, true) ~= nil then
            return true
        end
    end

    return false
end

local function try_fix_wall_materials(comp, entry)
    local key = string.lower(tostring(entry and entry.key or ""))
    if not contains_any_name_filter(key) then
        return false
    end

    if type(UEHelpers) ~= "table" or type(UEHelpers.GetMaterialByName) ~= "function" then
        return false
    end

    local num_ok, num_mats = pcall(function()
        return comp:GetNumMaterials()
    end)
    if not num_ok or type(num_mats) ~= "number" then
        return false
    end

    local replacement = nil
    local replacement_names = { "MI_White", "MI_WallWhite", "MI_Wall", "MI_Default" }
    for _, name in ipairs(replacement_names) do
        local ok_mat, mat = pcall(function()
            return UEHelpers.GetMaterialByName(name)
        end)
        if ok_mat and is_valid(mat) then
            replacement = mat
            break
        end
    end

    if not is_valid(replacement) then
        return false
    end

    local changed = false
    for i = 0, num_mats - 1 do
        local ok_mat, mat = pcall(function()
            return comp:GetMaterial(i)
        end)
        if ok_mat and is_black_material_object(mat) then
            local ok_set = call_method_if_valid(comp, "SetMaterial", i, replacement)
            if ok_set then
                changed = true
            end
        end
    end

    return changed
end

local contains_any_name_filter

local function try_force_material(comp, entry)
    if CONFIG.mesh_force_material_name == "" then
        return false
    end
    if CONFIG.mesh_force_material_require_name_filters and not contains_any_name_filter(string.lower(tostring(entry and entry.key or ""))) then
        return false
    end
    if type(UEHelpers) ~= "table" or type(UEHelpers.GetMaterialByName) ~= "function" then
        return false
    end

    local ok_mat, mat = pcall(function()
        return UEHelpers.GetMaterialByName(CONFIG.mesh_force_material_name)
    end)
    if not ok_mat or not is_valid(mat) then
        return false
    end

    local ok_num, num_mats = pcall(function()
        return comp:GetNumMaterials()
    end)
    if not ok_num or type(num_mats) ~= "number" then
        return false
    end

    local changed = false
    for i = 0, num_mats - 1 do
        if call_method_if_valid(comp, "SetMaterial", i, mat) then
            changed = true
        end
    end

    return changed
end

local function get_target_light_classes()
    local classes = {
        "PointLightComponent",
        "SpotLightComponent",
    }

    if CONFIG.include_rect_light_component then
        classes[#classes + 1] = "RectLightComponent"
    end

    if CONFIG.include_generic_light_component then
        classes[#classes + 1] = "LightComponent"
    end

    return classes
end

local function set_light_shadow(light_comp, enabled)
    local ok_fn = call_method_if_valid(light_comp, "SetCastShadows", enabled)
    local ok_field = set_field(light_comp, "CastShadows", enabled)
    return ok_fn or ok_field
end

local function get_entry_light_kind(entry)
    local key_lower = string.lower(tostring(entry.key or ""))

    if string.find(key_lower, "spotlightcomponent", 1, true) ~= nil then
        return "SpotLightComponent"
    end
    if string.find(key_lower, "rectlightcomponent", 1, true) ~= nil then
        return "RectLightComponent"
    end
    if string.find(key_lower, "pointlightcomponent", 1, true) ~= nil then
        return "PointLightComponent"
    end

    local comp = entry.comp
    if is_valid(comp) then
        local ok_outer, outer = get_field(comp, "OuterConeAngle")
        if ok_outer and type(outer) == "number" then
            return "SpotLightComponent"
        end

        local ok_width, width = get_field(comp, "SourceWidth")
        if ok_width and type(width) == "number" then
            return "RectLightComponent"
        end
    end

    return tostring(entry.class_name or "")
end

local function enable_light_component(light_comp)
    if not is_valid(light_comp) then
        return false
    end

    set_field(light_comp, "bAffectsWorld", true)
    set_field(light_comp, "bVisible", true)
    set_field(light_comp, "bEnabled", true)

    return is_valid(light_comp)
end

local function should_entry_cast_shadows(entry)
    local kind = get_entry_light_kind(entry)

    if CONFIG.respect_prepatch_shadow_state and kind == "SpotLightComponent" then
        local prepatch = entry.prepatch
        if prepatch ~= nil and prepatch.CastShadows ~= nil and prepatch.CastShadows ~= true then
            return false
        end
    end

    if kind == "RectLightComponent" then
        return CONFIG.rect_lights_cast_shadows == true
    end

    if kind == "PointLightComponent" then
        return CONFIG.point_lights_cast_shadows == true
    end

    if kind == "SpotLightComponent" then
        if not CONFIG.spot_lights_cast_shadows then
            return false
        end

        return true
    end

    return CONFIG.generic_lights_cast_shadows == true
end

local function tune_spotlight(light_comp, entry, track_stats)
    if not is_valid(light_comp) then
        return false
    end

    local tune_enabled = CONFIG.spotlight_tune_enabled
    local intensity = CONFIG.spotlight_intensity
    local indirect_lighting_intensity = CONFIG.spotlight_indirect_lighting_intensity
    local specular_scale = CONFIG.spotlight_specular_scale
    local attenuation_radius = CONFIG.spotlight_attenuation_radius
    local outer_cone_angle = CONFIG.spotlight_outer_cone_angle
    local inner_cone_angle = CONFIG.spotlight_inner_cone_angle
    local source_radius = CONFIG.spotlight_source_radius
    local soft_source_radius = CONFIG.spotlight_soft_source_radius
    local source_length = CONFIG.spotlight_source_length
    local tune_mode = CONFIG.spotlight_tune_mode
    local intensity_multiplier = CONFIG.spotlight_intensity_multiplier
    local indirect_lighting_multiplier = CONFIG.spotlight_indirect_lighting_multiplier
    local specular_multiplier = CONFIG.spotlight_specular_multiplier
    local attenuation_multiplier = CONFIG.spotlight_attenuation_multiplier
    local outer_cone_multiplier = CONFIG.spotlight_outer_cone_multiplier
    local inner_cone_multiplier = CONFIG.spotlight_inner_cone_multiplier
    local source_radius_multiplier = CONFIG.spotlight_source_radius_multiplier
    local soft_source_radius_multiplier = CONFIG.spotlight_soft_source_radius_multiplier
    local source_length_multiplier = CONFIG.spotlight_source_length_multiplier

    if not tune_enabled then
        return false
    end

    local record_stats = track_stats ~= false
    if record_stats then
        STATE.tune_attempted_last = STATE.tune_attempted_last + 1
    end
    local changed_any = false

    local function apply_tuned_value(field_name, value, setter_name)
        local ok = set_numeric_property(light_comp, field_name, value, setter_name)
        if ok then
            changed_any = true
            return true
        end

        if record_stats then
            STATE.tune_write_fail_last = STATE.tune_write_fail_last + 1
        end
        return false
    end

    local function apply_optional_ue_value(value, field_name, setter_name)
        if type(value) == "number" and value >= 0.0 then
            apply_tuned_value(field_name, value, setter_name)
        end
    end

    local function get_prepatch_numeric(field_name)
        if entry.prepatch_baseline ~= nil then
            local baseline_value = entry.prepatch_baseline[field_name]
            if type(baseline_value) == "number" then
                return baseline_value
            end
        end

        if entry.prepatch ~= nil then
            local prepatch_value = entry.prepatch[field_name]
            if type(prepatch_value) == "number" then
                return prepatch_value
            end
        end

        local ok, current = get_field(light_comp, field_name)
        if ok and type(current) == "number" then
            return current
        end

        return nil
    end

    local function apply_multiplier(multiplier, field_name, setter_name)
        if type(multiplier) ~= "number" or multiplier < 0.0 then
            return
        end

        local base_value = get_prepatch_numeric(field_name)
        if type(base_value) ~= "number" then
            return
        end

        local target_value = base_value * multiplier
        if math.abs(target_value - base_value) < 0.0001 then
            return
        end

        apply_tuned_value(field_name, target_value, setter_name)
    end

    local function apply_absolute_overrides()
        apply_optional_ue_value(intensity, "Intensity", "SetIntensity")
        apply_optional_ue_value(indirect_lighting_intensity, "IndirectLightingIntensity", "SetIndirectLightingIntensity")
        apply_optional_ue_value(specular_scale, "SpecularScale", "SetSpecularScale")
        apply_optional_ue_value(attenuation_radius, "AttenuationRadius", "SetAttenuationRadius")
        apply_optional_ue_value(outer_cone_angle, "OuterConeAngle", "SetOuterConeAngle")
        apply_optional_ue_value(inner_cone_angle, "InnerConeAngle", "SetInnerConeAngle")
        apply_optional_ue_value(source_radius, "SourceRadius", "SetSourceRadius")
        apply_optional_ue_value(soft_source_radius, "SoftSourceRadius", "SetSoftSourceRadius")
        apply_optional_ue_value(source_length, "SourceLength", "SetSourceLength")
    end

    if tune_mode == "multiplier" then
        apply_multiplier(intensity_multiplier, "Intensity", "SetIntensity")
        apply_multiplier(indirect_lighting_multiplier, "IndirectLightingIntensity", "SetIndirectLightingIntensity")
        apply_multiplier(specular_multiplier, "SpecularScale", "SetSpecularScale")
        apply_multiplier(attenuation_multiplier, "AttenuationRadius", "SetAttenuationRadius")
        apply_multiplier(outer_cone_multiplier, "OuterConeAngle", "SetOuterConeAngle")
        apply_multiplier(inner_cone_multiplier, "InnerConeAngle", "SetInnerConeAngle")
        apply_multiplier(source_radius_multiplier, "SourceRadius", "SetSourceRadius")
        apply_multiplier(soft_source_radius_multiplier, "SoftSourceRadius", "SetSoftSourceRadius")
        apply_multiplier(source_length_multiplier, "SourceLength", "SetSourceLength")
    end

    apply_absolute_overrides()

    if changed_any and record_stats then
        STATE.tune_changed_last = STATE.tune_changed_last + 1
    end

    return changed_any
end

local function enforce_light_megalights(light_comp, entry, record_stats)
    local track = record_stats ~= false
    if track then
        STATE.megalights_attempted_last = STATE.megalights_attempted_last + 1
    end

    local target_method = CONFIG.megalights_shadow_method
    local wrote_enabled = set_field(light_comp, "bAllowMegaLights", true)
    local wrote_method = set_field(light_comp, "MegaLightsShadowMethod", target_method)

    local has_enabled, current_enabled = get_field(light_comp, "bAllowMegaLights")
    local has_method, current_method = get_field(light_comp, "MegaLightsShadowMethod")
    local enabled_ok = wrote_enabled or (has_enabled and current_enabled == true)
    local method_ok = wrote_method or (has_method and tonumber(current_method) == target_method)
    local ok = enabled_ok and method_ok

    if track then
        if ok then
            STATE.megalights_forced_last = STATE.megalights_forced_last + 1
        else
            STATE.megalights_failed_last = STATE.megalights_failed_last + 1
        end
    end

    return ok
end

local function capture_spotlight_prepatch(entry, light_comp)
    if get_entry_light_kind(entry) ~= "SpotLightComponent" then
        entry.prepatch = nil
        return
    end

    local snapshot = {}
    local fields = {
        "Intensity",
        "IndirectLightingIntensity",
        "SpecularScale",
        "AttenuationRadius",
        "OuterConeAngle",
        "InnerConeAngle",
        "SourceRadius",
        "SoftSourceRadius",
        "SourceLength",
        "Mobility",
    }

    for _, field_name in ipairs(fields) do
        local ok, value = get_field(light_comp, field_name)
        if ok and value ~= nil then
            snapshot[field_name] = value
        end
    end

    local ok_cast, cast = get_field(light_comp, "CastShadows")
    if ok_cast then
        snapshot.CastShadows = cast
    end

    entry.prepatch = snapshot
    if entry.prepatch_baseline == nil then
        local baseline = {}
        for key, value in pairs(snapshot) do
            baseline[key] = value
        end
        entry.prepatch_baseline = baseline
    end
    STATE.prepatch_captured_last = STATE.prepatch_captured_last + 1
end

local function reset_spotlight_baselines()
    local reset_count = 0
    for _, entry in pairs(STATE.light_entries) do
        if entry.prepatch_baseline ~= nil then
            entry.prepatch_baseline = nil
            reset_count = reset_count + 1
        end
    end

    log(string.format("baseline reset entries=%d", reset_count))
end

local function patch_light_entry(entry)
    if entry.patched then
        return false
    end

    local light_comp = entry.comp
    if not is_valid(light_comp) then
        STATE.skipped_invalid = STATE.skipped_invalid + 1
        return false
    end

    capture_spotlight_prepatch(entry, light_comp)

    if not enable_light_component(light_comp) then
        STATE.skipped_invalid = STATE.skipped_invalid + 1
        entry.patched = false
        return false
    end
    STATE.enable_ops_last = STATE.enable_ops_last + 1
    entry.enabled_state = true

    enforce_light_megalights(light_comp, entry, true)

    if CONFIG.force_light_movable then
        local mobility_applied = call_method_if_valid(light_comp, "SetMobility", CONFIG.force_light_movable_value)
        if not mobility_applied then
            mobility_applied = set_field(light_comp, "Mobility", CONFIG.force_light_movable_value)
        end
    end

    if get_entry_light_kind(entry) == "SpotLightComponent" then
        if tune_spotlight(light_comp, entry) and not entry.spot_tuned then
            entry.spot_tuned = true
            STATE.spot_tuned_last = STATE.spot_tuned_last + 1
        end
    end

    entry.patched = true
    local cast_shadows = should_entry_cast_shadows(entry)
    if set_light_shadow(light_comp, cast_shadows) then
        STATE.shadow_ops_last = STATE.shadow_ops_last + 1
        entry.shadow_forced = cast_shadows
    else
        entry.shadow_forced = nil
    end
    return true
end

local function count_patched_total()
    local n = 0
    for _, entry in pairs(STATE.light_entries) do
        if entry.patched then
            n = n + 1
        end
    end
    return n
end

local function refresh_light_cache()
    STATE.refresh_seq = STATE.refresh_seq + 1
    local seen = {}
    local found = 0

    for _, class_name in ipairs(get_target_light_classes()) do
        for _, light_comp in ipairs(get_objects_of_class(class_name)) do
            if is_valid(light_comp) then
                local key = get_light_key(light_comp)
                if not seen[key] then
                    seen[key] = true
                    found = found + 1

                    local entry = STATE.light_entries[key]
                    if entry == nil then
                        STATE.light_entries[key] = {
                            key = key,
                            comp = light_comp,
                            class_name = class_name,
                            patched = false,
                            shadow_forced = false,
                            spot_tuned = false,
                            enabled_state = false,
                            last_seen = STATE.refresh_seq,
                        }
                    else
                        entry.comp = light_comp
                        entry.class_name = class_name
                        entry.last_seen = STATE.refresh_seq
                    end
                end
            end
        end
    end

    for key, entry in pairs(STATE.light_entries) do
        if entry.last_seen ~= STATE.refresh_seq or not is_valid(entry.comp) then
            STATE.light_entries[key] = nil
        end
    end

    STATE.lights_found = found
end



local function patch_cached_lights(force_reapply)
    STATE.lights_patched_last = 0
    STATE.skipped_invalid = 0
    STATE.spot_tuned_last = 0
    STATE.tune_attempted_last = 0
    STATE.tune_changed_last = 0
    STATE.tune_write_fail_last = 0
    STATE.prepatch_captured_last = 0
    STATE.enable_ops_last = 0
    STATE.shadow_ops_last = 0
    STATE.megalights_attempted_last = 0
    STATE.megalights_forced_last = 0
    STATE.megalights_failed_last = 0
    STATE.patched_runtime_last = 0

    if force_reapply then
        for _, entry in pairs(STATE.light_entries) do
            entry.patched = false
            entry.enabled_state = false
            entry.shadow_forced = nil
            entry.spot_tuned = false
        end
    end

    local patched_now = 0
    for _, entry in pairs(STATE.light_entries) do
        if patch_light_entry(entry) then
            patched_now = patched_now + 1
            STATE.patched_runtime_last = STATE.patched_runtime_last + 1
        end
    end

    STATE.lights_patched_last = patched_now
    STATE.lights_patched_total = count_patched_total()
end

local function refresh_shadow_slots()
    local active = 0
    local fill_active = 0
    local stale_keys = {}
    for key, entry in pairs(STATE.light_entries) do
        if entry.patched and is_valid(entry.comp) then
            if entry.enabled_state ~= true then
                if enable_light_component(entry.comp) then
                    entry.enabled_state = true
                    STATE.enable_ops_last = STATE.enable_ops_last + 1
                else
                    entry.patched = false
                    stale_keys[#stale_keys + 1] = key
                end
            end

            enforce_light_megalights(entry.comp, entry, false)

            local cast_shadows = should_entry_cast_shadows(entry)
            if cast_shadows then
                active = active + 1
            else
                fill_active = fill_active + 1
            end

            if entry.shadow_forced ~= cast_shadows then
                if set_light_shadow(entry.comp, cast_shadows) then
                    entry.shadow_forced = cast_shadows
                    STATE.shadow_ops_last = STATE.shadow_ops_last + 1
                elseif not is_valid(entry.comp) then
                    entry.patched = false
                    stale_keys[#stale_keys + 1] = key
                end
            end
        elseif entry.patched then
            entry.patched = false
            stale_keys[#stale_keys + 1] = key
        end
    end

    for _, key in ipairs(stale_keys) do
        STATE.light_entries[key] = nil
    end

    STATE.shadow_active = active
    STATE.shadow_fill_active = fill_active
end

local function set_renderer_megalights(enabled)
    STATE.compat_renderer_targets = 0
    STATE.compat_static_lighting_disabled = 0
    STATE.compat_distance_fields_enabled = 0
    STATE.compat_forward_shading_disabled = 0

    if not CONFIG.touch_renderer then
        STATE.renderer_scanned = 0
        STATE.renderer_enabled = 0
        return
    end

    if type(StaticFindObject) ~= "function" then
        STATE.renderer_scanned = 0
        STATE.renderer_enabled = 0
        return
    end

    local object_paths = {
        "/Script/Engine.Default__RendererSettings",
        "/Script/Engine.RendererSettings",
        "Default__RendererSettings",
    }

    local scanned = 0
    local enabled_count = 0

    for _, path in ipairs(object_paths) do
        local ok, obj = pcall(function()
            return StaticFindObject(path)
        end)
        if ok and is_valid(obj) then
            scanned = scanned + 1
            set_field(obj, "bEnableMegaLights", enabled)

            if CONFIG.force_lumen_compatibility then
                STATE.compat_renderer_targets = STATE.compat_renderer_targets + 1

                if CONFIG.lumen_disable_static_lighting and set_bool_property_confirmed(obj, "bAllowStaticLighting", false) then
                    STATE.compat_static_lighting_disabled = STATE.compat_static_lighting_disabled + 1
                end

                if CONFIG.lumen_enable_mesh_distance_fields and set_bool_property_confirmed(obj, "bGenerateMeshDistanceFields", true) then
                    STATE.compat_distance_fields_enabled = STATE.compat_distance_fields_enabled + 1
                end

                if CONFIG.lumen_disable_forward_shading and set_bool_property_confirmed(obj, "bForwardShading", false) then
                    STATE.compat_forward_shading_disabled = STATE.compat_forward_shading_disabled + 1
                end
            end

            if CONFIG.force_lumen_methods then
                local gi_method = CONFIG.lumen_gi_method_value
                local reflection_method = CONFIG.lumen_reflection_method_value
                if not set_field(obj, "DynamicGlobalIllumination", gi_method) then
                    set_field(obj, "DynamicGlobalIlluminationMethod", gi_method)
                end
                if not set_field(obj, "Reflections", reflection_method) then
                    set_field(obj, "ReflectionMethod", reflection_method)
                end
            end

            local has_enabled, current = get_field(obj, "bEnableMegaLights")
            if has_enabled and current == true then
                enabled_count = enabled_count + 1
            end
        end
    end

    STATE.renderer_scanned = scanned
    STATE.renderer_enabled = enabled_count
end

local function apply_world_lumen_compatibility()
    STATE.compat_world_targets = 0
    STATE.compat_no_precomputed_enabled = 0

    if not CONFIG.force_lumen_compatibility then
        return
    end

    if not CONFIG.lumen_force_no_precomputed_lighting then
        return
    end

    for _, world_settings in ipairs(get_objects_of_class("WorldSettings")) do
        if is_valid(world_settings) then
            STATE.compat_world_targets = STATE.compat_world_targets + 1
            if set_bool_property_confirmed(world_settings, "bForceNoPrecomputedLighting", true) then
                STATE.compat_no_precomputed_enabled = STATE.compat_no_precomputed_enabled + 1
            end
        end
    end
end

local function apply_ppv_settings(ppv, settings_field_name, enabled)
    local ok_settings, settings = get_field(ppv, settings_field_name)
    if not ok_settings or settings == nil then
        return false
    end

    local wrote_override = pcall(function()
        settings.bOverride_bMegaLights = true
    end)
    local wrote_value = pcall(function()
        settings.bMegaLights = enabled
    end)

    local wrote_lumen_override_gi = true
    local wrote_lumen_value_gi = true
    local wrote_lumen_override_reflection = true
    local wrote_lumen_value_reflection = true
    local wrote_lumen_override_scene_detail = true
    local wrote_lumen_value_scene_detail = true
    local wrote_lumen_override_diffuse_boost = true
    local wrote_lumen_value_diffuse_boost = true
    local wrote_lumen_override_skylight_leaking = true
    local wrote_lumen_value_skylight_leaking = true
    local wrote_lumen_override_max_trace_distance = true
    local wrote_lumen_value_max_trace_distance = true
    if CONFIG.force_lumen_methods then
        wrote_lumen_override_gi = pcall(function()
            settings.bOverride_DynamicGlobalIlluminationMethod = true
        end)
        wrote_lumen_value_gi = pcall(function()
            settings.DynamicGlobalIlluminationMethod = CONFIG.lumen_gi_method_value
        end)
        wrote_lumen_override_reflection = pcall(function()
            settings.bOverride_ReflectionMethod = true
        end)
        wrote_lumen_value_reflection = pcall(function()
            settings.ReflectionMethod = CONFIG.lumen_reflection_method_value
        end)
        wrote_lumen_override_scene_detail = pcall(function()
            settings.bOverride_LumenSceneDetail = true
        end)
        wrote_lumen_value_scene_detail = pcall(function()
            settings.LumenSceneDetail = CONFIG.lumen_scene_detail
        end)
        wrote_lumen_override_diffuse_boost = pcall(function()
            settings.bOverride_LumenDiffuseColorBoost = true
        end)
        wrote_lumen_value_diffuse_boost = pcall(function()
            settings.LumenDiffuseColorBoost = CONFIG.lumen_diffuse_color_boost
        end)
        wrote_lumen_override_skylight_leaking = pcall(function()
            settings.bOverride_LumenSkylightLeaking = true
        end)
        wrote_lumen_value_skylight_leaking = pcall(function()
            settings.LumenSkylightLeaking = CONFIG.lumen_skylight_leaking
        end)
        wrote_lumen_override_max_trace_distance = pcall(function()
            settings.bOverride_LumenMaxTraceDistance = true
        end)
        wrote_lumen_value_max_trace_distance = pcall(function()
            settings.LumenMaxTraceDistance = CONFIG.lumen_max_trace_distance
        end)
    end

    local wrote_back = set_field(ppv, settings_field_name, settings)

    local ok_check, current = pcall(function()
        local _, readback = get_field(ppv, settings_field_name)
        if readback ~= nil then
            return readback.bMegaLights
        end
        return settings.bMegaLights
    end)

    if ok_check and current == enabled then
        return true
    end

    if wrote_override and wrote_value and wrote_lumen_override_gi and wrote_lumen_value_gi and wrote_lumen_override_reflection and wrote_lumen_value_reflection and wrote_lumen_override_scene_detail and wrote_lumen_value_scene_detail and wrote_lumen_override_diffuse_boost and wrote_lumen_value_diffuse_boost and wrote_lumen_override_skylight_leaking and wrote_lumen_value_skylight_leaking and wrote_lumen_override_max_trace_distance and wrote_lumen_value_max_trace_distance then
        return true
    end

    return wrote_back and
        (wrote_override or wrote_value or wrote_lumen_override_gi or wrote_lumen_value_gi or wrote_lumen_override_reflection or wrote_lumen_value_reflection or wrote_lumen_override_scene_detail or wrote_lumen_value_scene_detail or wrote_lumen_override_diffuse_boost or wrote_lumen_value_diffuse_boost or wrote_lumen_override_skylight_leaking or wrote_lumen_value_skylight_leaking or wrote_lumen_override_max_trace_distance or wrote_lumen_value_max_trace_distance)
end

local function set_postprocess_megalights(enabled)
    if not CONFIG.touch_postprocess_volume then
        STATE.ppv_scanned = 0
        STATE.ppv_enabled = 0
        return
    end

    local scanned = 0
    local enabled_count = 0

    for _, ppv in ipairs(get_objects_of_class("PostProcessVolume")) do
        if is_valid(ppv) then
            scanned = scanned + 1

            if CONFIG.force_ppv_enabled then
                set_field(ppv, "bEnabled", true)
            end

            local ok_lower = apply_ppv_settings(ppv, "settings", enabled)
            local ok_upper = apply_ppv_settings(ppv, "Settings", enabled)
            if ok_lower or ok_upper then
                enabled_count = enabled_count + 1
            end
        end
    end

    STATE.ppv_scanned = scanned
    STATE.ppv_enabled = enabled_count
end

local function run_console_command(command)
    if type(command) ~= "string" or command == "" then
        return false
    end

    local function get_world_context()
        local world_settings = get_objects_of_class("WorldSettings")
        if #world_settings > 0 and is_valid(world_settings[1]) then
            return world_settings[1]
        end
        return nil
    end

    local world_context = get_world_context()
    if type(StaticFindObject) == "function" then
        local kismet_paths = {
            "/Script/Engine.Default__KismetSystemLibrary",
            "/Script/Engine.KismetSystemLibrary",
            "Default__KismetSystemLibrary",
        }
        for _, path in ipairs(kismet_paths) do
            local ok_obj, ksl = pcall(function()
                return StaticFindObject(path)
            end)
            if ok_obj and is_valid(ksl) then
                if call_method_if_valid(ksl, "ExecuteConsoleCommand", world_context, command, nil) then
                    return true
                end
            end
        end
    end

    for _, controller in ipairs(get_objects_of_class("PlayerController")) do
        if is_valid(controller) and call_method_if_valid(controller, "ConsoleCommand", command) then
            return true
        end
    end

    return false
end

local function extract_level_name_from_full_name(full_name)
    if type(full_name) ~= "string" or full_name == "" then
        return nil
    end

    local path = full_name
    local after_space = string.match(full_name, "%s+(.+)")
    if after_space ~= nil and after_space ~= "" then
        path = after_space
    end

    local before_persistent = string.match(path, "([^:]+):PersistentLevel")
    if before_persistent ~= nil and before_persistent ~= "" then
        path = before_persistent
    end

    local name = string.match(path, "%.([%w_]+)$")
    if name == nil or name == "" then
        name = string.match(path, "/([%w_]+)$")
    end

    if name == nil or name == "" then
        return nil
    end

    return name
end

local function get_world_context_object()
    local world_settings = get_objects_of_class("WorldSettings")
    if #world_settings > 0 and is_valid(world_settings[1]) then
        return world_settings[1]
    end

    local controllers = get_objects_of_class("PlayerController")
    for _, controller in ipairs(controllers) do
        if is_valid(controller) then
            return controller
        end
    end

    return nil
end

local function get_current_level_name()
    local world_context = nil

    if type(UEHelpers) == "table" then
        local ok_world = true
        if type(UEHelpers.GetWorldContextObject) == "function" then
            ok_world, world_context = pcall(UEHelpers.GetWorldContextObject)
        elseif type(UEHelpers.GetWorld) == "function" then
            ok_world, world_context = pcall(UEHelpers.GetWorld)
        end
        if not ok_world then
            world_context = nil
        end
    end

    if not is_valid(world_context) then
        world_context = get_world_context_object()
    end

    if not is_valid(world_context) then
        return nil
    end

    local gameplay_statics = nil
    if type(UEHelpers) == "table" and type(UEHelpers.GetGameplayStatics) == "function" then
        local ok_gs, gs = pcall(UEHelpers.GetGameplayStatics, false)
        if ok_gs and is_valid(gs) then
            gameplay_statics = gs
        end
    end

    if gameplay_statics == nil and type(StaticFindObject) == "function" then
        local paths = {
            "/Script/Engine.Default__GameplayStatics",
            "/Script/Engine.GameplayStatics",
            "Default__GameplayStatics",
        }
        for _, path in ipairs(paths) do
            local ok, obj = pcall(StaticFindObject, path)
            if ok and is_valid(obj) then
                gameplay_statics = obj
                break
            end
        end
    end

    if gameplay_statics == nil or not is_valid(gameplay_statics) then
        return nil
    end

    local ok_level, level_name = pcall(function()
        return gameplay_statics:GetCurrentLevelName(world_context, true)
    end)
    if ok_level and type(level_name) == "string" and level_name ~= "" then
        return level_name
    end

    local ok_full, full_name = pcall(function()
        return world_context:GetFullName()
    end)
    if ok_full and type(full_name) == "string" then
        local parsed_name = extract_level_name_from_full_name(full_name)
        if parsed_name ~= nil then
            return parsed_name
        end
    end

    local world_settings = get_objects_of_class("WorldSettings")
    if #world_settings > 0 and is_valid(world_settings[1]) then
        local ok_ws, ws_name = pcall(function()
            return world_settings[1]:GetFullName()
        end)
        if ok_ws and type(ws_name) == "string" then
            local parsed_name = extract_level_name_from_full_name(ws_name)
            if parsed_name ~= nil then
                return parsed_name
            end
        end
    end

    return nil
end

local function is_autofix_level_excluded(name)
    if type(name) ~= "string" or name == "" then
        return true
    end

    local lowered = string.lower(name)
    for _, raw in ipairs(CONFIG.mesh_scope_autofix_exclude_names or {}) do
        if type(raw) == "string" then
            local filter = string.lower(raw)
            if filter ~= "" and string.find(lowered, filter, 1, true) ~= nil then
                return true
            end
        end
    end

    return false
end

local function get_best_level_name_from_mesh_entries()
    local counts = {}
    local best_name = nil
    local best_count = 0

    for _, entry in pairs(STATE.mesh_entries) do
        if entry ~= nil and type(entry.key) == "string" then
            local parsed = extract_level_name_from_full_name(entry.key)
            if parsed ~= nil and not is_autofix_level_excluded(parsed) then
                counts[parsed] = (counts[parsed] or 0) + 1
                if counts[parsed] > best_count then
                    best_count = counts[parsed]
                    best_name = parsed
                end
            end
        end
    end

    return best_name, best_count
end

-- fog logic moved to tg_fog.lua (functions moved to module)

local function maybe_verify_distance_fields(on_patch)
    if not CONFIG.distance_fields_verification then
        STATE.df_verify_skipped_reason = "disabled"
        return
    end

    if CONFIG.distance_fields_verify_once and STATE.df_verified_once then
        STATE.df_verify_skipped_reason = "verify_once_done"
        return
    end

    local now_ms = get_time_ms()
    local should_log_atlas = false
    if on_patch and CONFIG.distance_fields_log_atlas_on_patch then
        should_log_atlas = true
    end
    if CONFIG.distance_fields_log_atlas_interval_ms > 0 and now_ms - STATE.df_last_atlas_log_time >= CONFIG.distance_fields_log_atlas_interval_ms then
        should_log_atlas = true
    end

    if should_log_atlas then
        if run_console_command("r.DistanceFields.LogAtlasStats 1") then
            STATE.df_atlas_log_requests = STATE.df_atlas_log_requests + 1
            STATE.df_last_atlas_log_time = now_ms
        else
            safe_inc_reason(STATE.df_fail_reasons, "atlas_log_command_failed")
        end
    end

    local classes_to_scan = {
        "StaticMeshComponent",
        "InstancedStaticMeshComponent",
        "HierarchicalInstancedStaticMeshComponent",
    }

    local flags_seen = 0
    for _, class_name in ipairs(classes_to_scan) do
        for _, obj in ipairs(get_objects_of_class(class_name)) do
            if is_valid(obj) then
                STATE.df_component_scan_count = STATE.df_component_scan_count + 1
                local found_flag = false

                local probe_fields = {
                    "bAffectDistanceFieldLighting",
                    "bCastDistanceFieldIndirectShadow",
                    "DistanceFieldSelfShadowBias",
                    "DistanceFieldIndirectShadowMinVisibility",
                }
                for _, field_name in ipairs(probe_fields) do
                    local ok_probe, _ = get_field(obj, field_name)
                    if ok_probe then
                        found_flag = true
                    end
                end

                local ok_mesh, mesh = get_field(obj, "StaticMesh")
                if ok_mesh and is_valid(mesh) then
                    local ok_mesh_df, _ = get_field(mesh, "bGenerateMeshDistanceField")
                    if ok_mesh_df then
                        found_flag = true
                    end
                end

                if found_flag then
                    flags_seen = flags_seen + 1
                end
            end
        end
    end

    STATE.df_components_with_df_flags = flags_seen
    STATE.df_verify_runs = STATE.df_verify_runs + 1
    STATE.df_last_verify_time = now_ms
    STATE.df_verify_skipped_reason = ""
    if CONFIG.distance_fields_verify_once then
        STATE.df_verified_once = true
    end
end

local function update_renderer_capability_counters()
    STATE.capability_scan_runs = (STATE.capability_scan_runs or 0) + 1
    STATE.renderer_df_supported = (STATE.renderer_df_supported or 0) + STATE.compat_distance_fields_enabled
    STATE.renderer_megalights_supported = (STATE.renderer_megalights_supported or 0) + STATE.renderer_enabled
    STATE.ppv_megalights_supported = (STATE.ppv_megalights_supported or 0) + STATE.ppv_enabled
end

local function maybe_enable_renderer()
    set_renderer_megalights(true)
    apply_world_lumen_compatibility()
    set_postprocess_megalights(true)
    update_renderer_capability_counters()
end

local function run_apply()
    if STATE.in_progress then
        log("patch skipped: already in progress")
        return
    end

    STATE.in_progress = true
    STATE.last_error = ""
    STATE.apply_runs = STATE.apply_runs + 1
    STATE.skylight_fail_reasons = {}
    STATE.fog_fail_reasons = {}
    STATE.df_fail_reasons = {}
    reset_runtime_diag_counters()

    local ok, err = pcall(function()
        normalize_config()
        refresh_light_cache()
        patch_cached_lights(true)
        if CONFIG.mesh_runtime_pass then
            refresh_mesh_cache()
            patch_cached_mesh_components(true)
        end
        maybe_enable_renderer()
        maybe_patch_skylights(true)
        maybe_patch_fog(true)
        maybe_verify_distance_fields(true)
        refresh_shadow_slots()

        log(string.format(
            "patch runs=%d found=%d patched_total=%d patched_new=%d patched_runtime=%d shadow_active=%d shadow_fill_active=%d spot_shadows=%s spot_tuned=%d tune_attempted=%d tune_changed=%d tune_write_fail=%d enable_ops=%d shadow_ops=%d megalights=%d/%d failed=%d method=%d renderer_enable=true:%d/%d ppv_enable=true:%d/%d compat=%s static_off=%d/%d dist_fields_on=%d/%d forward_off=%d/%d world_no_precomputed=%d/%d",
            STATE.apply_runs,
            STATE.lights_found,
            STATE.lights_patched_total,
            STATE.lights_patched_last,
            STATE.patched_runtime_last,
            STATE.shadow_active,
            STATE.shadow_fill_active,
            tostring(CONFIG.spot_lights_cast_shadows),
            STATE.spot_tuned_last,
            STATE.tune_attempted_last,
            STATE.tune_changed_last,
            STATE.tune_write_fail_last,
            STATE.enable_ops_last,
            STATE.shadow_ops_last,
            STATE.megalights_forced_last,
            STATE.megalights_attempted_last,
            STATE.megalights_failed_last,
            CONFIG.megalights_shadow_method,
            STATE.renderer_enabled,
            STATE.renderer_scanned,
            STATE.ppv_enabled,
            STATE.ppv_scanned,
            tostring(CONFIG.force_lumen_compatibility),
            STATE.compat_static_lighting_disabled,
            STATE.compat_renderer_targets,
            STATE.compat_distance_fields_enabled,
            STATE.compat_renderer_targets,
            STATE.compat_forward_shading_disabled,
            STATE.compat_renderer_targets,
            STATE.compat_no_precomputed_enabled,
            STATE.compat_world_targets
        ))
        log(string.format(
            "patch skipped invalid=%d",
            STATE.skipped_invalid
        ))
        log(string.format(
            "patch mesh pass=%s found=%d candidates=%d foliage_found=%d foliage_candidates=%d skeletal_found=%d skeletal_candidates=%d patched_total=%d patched_new=%d apply_ops=%d write_fail=%d filtered_out=%d cull_ops=%d cull_fail=%d bounds_ops=%d bounds_fail=%d thick_ops=%d thick_fail=%d",
            tostring(CONFIG.mesh_runtime_pass),
            STATE.mesh_components_found,
            STATE.mesh_components_candidates,
            STATE.mesh_foliage_components_found,
            STATE.mesh_foliage_components_candidates,
            STATE.mesh_skeletal_components_found,
            STATE.mesh_skeletal_components_candidates,
            STATE.mesh_components_patched_total,
            STATE.mesh_components_patched_last,
            STATE.mesh_force_apply_ops_last,
            STATE.mesh_write_fail_last,
            STATE.mesh_filter_skipped_last,
            STATE.mesh_cull_distance_ops_last,
            STATE.mesh_cull_distance_fail_last,
            STATE.mesh_bounds_scale_ops_last,
            STATE.mesh_bounds_scale_fail_last,
            STATE.mesh_pseudo_thickness_ops_last,
            STATE.mesh_pseudo_thickness_fail_last
        ))
        log(string.format(
            "patch sky found=%d valid=%d patched=%d movable=%d realtime=%d recapture=%d/%d scale_int=%d scale_ind=%d fog found=%d valid=%d enabled=%d volumetric=%d lumen_fields=%d df runs=%d atlas_req=%d scan=%d flags=%d df_skip=%s",
            STATE.skylight_found,
            STATE.skylight_valid,
            STATE.skylight_patched,
            STATE.skylight_movable_forced,
            STATE.skylight_realtime_enabled,
            STATE.skylight_recapture_ok,
            STATE.skylight_recapture_attempted,
            STATE.skylight_intensity_scaled,
            STATE.skylight_indirect_scaled,
            STATE.fog_actors_found,
            STATE.fog_valid,
            STATE.fog_enabled,
            STATE.fog_volumetric_enabled,
            STATE.fog_lumen_fields_seen,
            STATE.df_verify_runs,
            STATE.df_atlas_log_requests,
            STATE.df_component_scan_count,
            STATE.df_components_with_df_flags,
            tostring(STATE.df_verify_skipped_reason)
        ))
    end)

    STATE.in_progress = false
    if not ok then
        STATE.last_error = tostring(err)
        log("patch failed: " .. STATE.last_error)
        return
    end

    if not STATE.manager_running then
        STATE.manager_running = true
        STATE.ms_since_refresh = 0
        ExecuteWithDelay(100, function()
            local function tick()
                if not STATE.manager_running then
                    return
                end

                local tick_ok, tick_err = pcall(function()
                    STATE.ms_since_refresh = STATE.ms_since_refresh + CONFIG.shadow_tick_ms
                    local refreshed = false

                    if STATE.ms_since_refresh >= CONFIG.cache_refresh_ms then
                        STATE.ms_since_refresh = 0
                        refresh_light_cache()
                        patch_cached_lights(false)
                        if CONFIG.mesh_runtime_pass then
                            refresh_mesh_cache()
                            if CONFIG.mesh_patch_on_refresh then
                                patch_cached_mesh_components(CONFIG.mesh_reapply_each_refresh)
                            end
                        end
                        maybe_enable_renderer()
                        maybe_patch_skylights(false)
                        maybe_patch_fog(false)
                        maybe_verify_distance_fields(false)
                        refreshed = true
                    end

                    if CONFIG.live_shadow_sync or refreshed then
                        refresh_shadow_slots()
                    end
                end)

                if not tick_ok then
                    STATE.last_error = tostring(tick_err)
                    log("shadow manager tick failed: " .. STATE.last_error)
                end

                ExecuteWithDelay(CONFIG.shadow_tick_ms, tick)
            end

            tick()
        end)
    end
end

local function run_status()
    normalize_config()
    log(string.format(
        "status runs=%d found=%d patched_total=%d patched_new=%d patched_runtime=%d shadow_active=%d shadow_fill_active=%d spot_shadows=%s spot_tuned=%d tune_attempted=%d tune_changed=%d tune_write_fail=%d enable_ops=%d shadow_ops=%d megalights=%d/%d failed=%d point_shadows=%s rect_shadows=%s spot_tune=%s movable=%s movable_value=%d respect_prepatch_shadow=%s spot_mode=%s shadow_tick_ms=%d cache_refresh_ms=%d live_shadow_sync=%s force_lumen=%s force_lumen_compat=%s static_off_req=%s no_precomputed_req=%s dist_fields_req=%s forward_off_req=%s lumen_gi=%d lumen_reflection=%d lumen_scene_detail=%.3f lumen_diffuse_boost=%.3f lumen_skylight_leaking=%.3f lumen_max_trace_distance=%.3f method=%d renderer_enable=true:%d/%d ppv_enable=true:%d/%d compat_static_off=%d/%d compat_dist_fields=%d/%d compat_forward_off=%d/%d compat_no_precomputed=%d/%d spot_cfg_abs[intensity=%.3f indirect=%.3f specular=%.3f attenuation=%.3f outer=%.3f inner=%.3f source=%.3f soft=%.3f length=%.3f] spot_cfg_mul[intensity=%.3f indirect=%.3f specular=%.3f attenuation=%.3f outer=%.3f inner=%.3f source=%.3f soft=%.3f length=%.3f]",
        STATE.apply_runs,
        STATE.lights_found,
        STATE.lights_patched_total,
        STATE.lights_patched_last,
        STATE.patched_runtime_last,
        STATE.shadow_active,
        STATE.shadow_fill_active,
        tostring(CONFIG.spot_lights_cast_shadows),
        STATE.spot_tuned_last,
        STATE.tune_attempted_last,
        STATE.tune_changed_last,
        STATE.tune_write_fail_last,
        STATE.enable_ops_last,
        STATE.shadow_ops_last,
        STATE.megalights_forced_last,
        STATE.megalights_attempted_last,
        STATE.megalights_failed_last,
        tostring(CONFIG.point_lights_cast_shadows),
        tostring(CONFIG.rect_lights_cast_shadows),
        tostring(CONFIG.spotlight_tune_enabled),
        tostring(CONFIG.force_light_movable),
        CONFIG.force_light_movable_value,
        tostring(CONFIG.respect_prepatch_shadow_state),
        tostring(CONFIG.spotlight_tune_mode),
        CONFIG.shadow_tick_ms,
        CONFIG.cache_refresh_ms,
        tostring(CONFIG.live_shadow_sync),
        tostring(CONFIG.force_lumen_methods),
        tostring(CONFIG.force_lumen_compatibility),
        tostring(CONFIG.lumen_disable_static_lighting),
        tostring(CONFIG.lumen_force_no_precomputed_lighting),
        tostring(CONFIG.lumen_enable_mesh_distance_fields),
        tostring(CONFIG.lumen_disable_forward_shading),
        CONFIG.lumen_gi_method_value,
        CONFIG.lumen_reflection_method_value,
        CONFIG.lumen_scene_detail,
        CONFIG.lumen_diffuse_color_boost,
        CONFIG.lumen_skylight_leaking,
        CONFIG.lumen_max_trace_distance,
        CONFIG.megalights_shadow_method,
        STATE.renderer_enabled,
        STATE.renderer_scanned,
        STATE.ppv_enabled,
        STATE.ppv_scanned,
        STATE.compat_static_lighting_disabled,
        STATE.compat_renderer_targets,
        STATE.compat_distance_fields_enabled,
        STATE.compat_renderer_targets,
        STATE.compat_forward_shading_disabled,
        STATE.compat_renderer_targets,
        STATE.compat_no_precomputed_enabled,
        STATE.compat_world_targets,
        CONFIG.spotlight_intensity,
        CONFIG.spotlight_indirect_lighting_intensity,
        CONFIG.spotlight_specular_scale,
        CONFIG.spotlight_attenuation_radius,
        CONFIG.spotlight_outer_cone_angle,
        CONFIG.spotlight_inner_cone_angle,
        CONFIG.spotlight_source_radius,
        CONFIG.spotlight_soft_source_radius,
        CONFIG.spotlight_source_length,
        CONFIG.spotlight_intensity_multiplier,
        CONFIG.spotlight_indirect_lighting_multiplier,
        CONFIG.spotlight_specular_multiplier,
        CONFIG.spotlight_attenuation_multiplier,
        CONFIG.spotlight_outer_cone_multiplier,
        CONFIG.spotlight_inner_cone_multiplier,
        CONFIG.spotlight_source_radius_multiplier,
        CONFIG.spotlight_soft_source_radius_multiplier,
        CONFIG.spotlight_source_length_multiplier
    ))
    log(string.format(
        "status skipped invalid=%d",
        STATE.skipped_invalid
    ))
    log(string.format(
        "status sky pass=%s force_movable=%s realtime=%s recapture_on_patch=%s recapture_interval_ms=%d found=%d valid=%d patched=%d movable=%d realtime_ok=%d recapture_ok=%d/%d scale_int=%d scale_ind=%d sky_write_fail=%d fog pass=%s exp_fog=%s volumetric=%s lumen_helpers=%s found=%d valid=%d enabled=%d volumetric_ok=%d lumen_fields=%d fog_write_fail=%d df pass=%s verify_once=%s atlas_on_patch=%s atlas_interval_ms=%d runs=%d atlas_req=%d scan=%d flags=%d skip=%s",
        tostring(CONFIG.skylight_runtime_pass),
        tostring(CONFIG.skylight_force_movable),
        tostring(CONFIG.skylight_enable_realtime_capture),
        tostring(CONFIG.skylight_recapture_on_patch),
        CONFIG.skylight_recapture_interval_ms,
        STATE.skylight_found,
        STATE.skylight_valid,
        STATE.skylight_patched,
        STATE.skylight_movable_forced,
        STATE.skylight_realtime_enabled,
        STATE.skylight_recapture_ok,
        STATE.skylight_recapture_attempted,
        STATE.skylight_intensity_scaled,
        STATE.skylight_indirect_scaled,
        STATE.skylight_write_fail,
        tostring(CONFIG.fog_runtime_pass),
        tostring(CONFIG.fog_enable_exponential_height_fog),
        tostring(CONFIG.fog_enable_volumetric_fog),
        tostring(CONFIG.fog_try_lumen_fog_helpers),
        STATE.fog_actors_found,
        STATE.fog_valid,
        STATE.fog_enabled,
        STATE.fog_volumetric_enabled,
        STATE.fog_lumen_fields_seen,
        STATE.fog_write_fail,
        tostring(CONFIG.distance_fields_verification),
        tostring(CONFIG.distance_fields_verify_once),
        tostring(CONFIG.distance_fields_log_atlas_on_patch),
        CONFIG.distance_fields_log_atlas_interval_ms,
        STATE.df_verify_runs,
        STATE.df_atlas_log_requests,
        STATE.df_component_scan_count,
        STATE.df_components_with_df_flags,
        tostring(STATE.df_verify_skipped_reason)
    ))
    log(string.format(
        "status mesh pass=%s refresh_patch=%s reapply=%s skip_movable=%s include_skeletal=%s filters=%d bounds_force=%s bounds_scale=%.3f never_cull=%s cull_vol_off=%s max_draw_zero=%s instance_cull_zero=%s pseudo_thickness=%s axis=%s thick_mul=%.3f found=%d candidates=%d foliage_found=%d foliage_candidates=%d skeletal_found=%d skeletal_candidates=%d patched_total=%d patched_last=%d apply_ops=%d write_fail=%d filtered_out=%d cull_ops=%d cull_fail=%d bounds_ops=%d bounds_fail=%d thick_ops=%d thick_fail=%d",
        tostring(CONFIG.mesh_runtime_pass),
        tostring(CONFIG.mesh_patch_on_refresh),
        tostring(CONFIG.mesh_reapply_each_refresh),
        tostring(CONFIG.mesh_skip_movable),
        tostring(CONFIG.mesh_include_skeletal_components),
        (type(CONFIG.mesh_name_filters) == "table" and #CONFIG.mesh_name_filters or 0),
        tostring(CONFIG.mesh_force_bounds_scale),
        CONFIG.mesh_bounds_scale,
        tostring(CONFIG.mesh_force_never_distance_cull),
        tostring(CONFIG.mesh_disable_cull_distance_volume),
        tostring(CONFIG.mesh_force_zero_max_draw_distance),
        tostring(CONFIG.mesh_force_zero_instance_cull_distances),
        tostring(CONFIG.mesh_pseudo_thickness_enabled),
        tostring(CONFIG.mesh_pseudo_thickness_axis),
        CONFIG.mesh_pseudo_thickness_multiplier,
        STATE.mesh_components_found,
        STATE.mesh_components_candidates,
        STATE.mesh_foliage_components_found,
        STATE.mesh_foliage_components_candidates,
        STATE.mesh_skeletal_components_found,
        STATE.mesh_skeletal_components_candidates,
        STATE.mesh_components_patched_total,
        STATE.mesh_components_patched_last,
        STATE.mesh_force_apply_ops_last,
        STATE.mesh_write_fail_last,
        STATE.mesh_filter_skipped_last,
        STATE.mesh_cull_distance_ops_last,
        STATE.mesh_cull_distance_fail_last,
        STATE.mesh_bounds_scale_ops_last,
        STATE.mesh_bounds_scale_fail_last,
        STATE.mesh_pseudo_thickness_ops_last,
        STATE.mesh_pseudo_thickness_fail_last
    ))

    if STATE.last_error ~= "" then
        log("status last_error=" .. STATE.last_error)
    end
end

local function run_prepatch_dump()
    local function fmt_num(v)
        if type(v) == "number" then
            return string.format("%.3f", v)
        end
        return "n/a"
    end

    local function fmt_any(v)
        if v == nil then
            return "n/a"
        end
        return tostring(v)
    end

    local total = 0
    for _, entry in pairs(STATE.light_entries) do
        local snap = entry.prepatch
        if snap ~= nil then
            total = total + 1
            log(string.format(
                "prepatch[%d] key=%s intensity=%s indirect=%s specular=%s attenuation=%s outer=%s inner=%s source=%s soft=%s length=%s mobility=%s cast=%s",
                total,
                tostring(entry.key),
                fmt_num(snap.Intensity),
                fmt_num(snap.IndirectLightingIntensity),
                fmt_num(snap.SpecularScale),
                fmt_num(snap.AttenuationRadius),
                fmt_num(snap.OuterConeAngle),
                fmt_num(snap.InnerConeAngle),
                fmt_num(snap.SourceRadius),
                fmt_num(snap.SoftSourceRadius),
                fmt_num(snap.SourceLength),
                fmt_any(snap.Mobility),
                fmt_any(snap.CastShadows)
            ))
        end
    end

    log(string.format("prepatch snapshots=%d shown=%d", total, total))
    if total == 0 then
        log("prepatch none captured yet; run tajsgraph.apply first")
    end
end

-- Autocomplete functionality moved to tg_autocomplete module (tg_autocomplete.lua)
-- local helpers and functions were removed from main.lua to keep the file smaller.

local function parse_mesh_find_request(parameters)
    local query = string.lower(trim(CONFIG.mesh_find_default_query or ""))
    local limit = CONFIG.mesh_find_default_limit

    if type(limit) ~= "number" then
        limit = 40
    end
    limit = math.max(1, math.floor(limit))

    if type(parameters) ~= "table" then
        return query, limit
    end

    local first = trim(parameters[1] or "")
    local second = trim(parameters[2] or "")

    if first ~= "" then
        local maybe_limit = tonumber(first)
        if maybe_limit ~= nil then
            limit = math.max(1, math.floor(maybe_limit))
        else
            query = string.lower(first)
        end
    end

    if second ~= "" then
        local maybe_limit = tonumber(second)
        if maybe_limit ~= nil then
            limit = math.max(1, math.floor(maybe_limit))
        else
            query = string.lower(second)
        end
    end

    return query, limit
end

local function parse_filter_tokens(parameters)
    local filters = {}
    if type(parameters) ~= "table" then
        return filters
    end

    for _, raw in ipairs(parameters) do
        if type(raw) == "string" then
            for token in string.gmatch(raw, "[^,]+") do
                local value = trim(token)
                if value ~= "" then
                    filters[#filters + 1] = value
                end
            end
        end
    end

    return filters
end

local function run_mesh_find(parameters)
    normalize_config()
    refresh_mesh_cache()

    local query, limit = parse_mesh_find_request(parameters)
    local shown = 0
    local total_matches = 0
    local class_counts = {}

    log(string.format("mesh find query='%s' limit=%d", tostring(query), limit))

    for _, entry in pairs(STATE.mesh_entries) do
        local key = tostring(entry.key or "")
        local key_lower = string.lower(key)
        local class_name = tostring(entry.class_name or "")
        local class_lower = string.lower(class_name)
        local matches = query == "" or string.find(key_lower, query, 1, true) ~= nil or
            string.find(class_lower, query, 1, true) ~= nil

        if matches then
            total_matches = total_matches + 1
            class_counts[class_name] = (class_counts[class_name] or 0) + 1
            local rejection_reason = get_mesh_candidate_rejection_reason(entry)
            local is_candidate = rejection_reason == nil

            if shown < limit then
                shown = shown + 1
                log(string.format("mesh find [%d] class=%s candidate=%s patched=%s skip_reason=%s key=%s", shown,
                    class_name, tostring(is_candidate), tostring(entry.patched == true), tostring(rejection_reason or ""),
                    key))
            end
        end
    end

    local class_list = {}
    for class_name, count in pairs(class_counts) do
        class_list[#class_list + 1] = { class_name = class_name, count = count }
    end
    table.sort(class_list, function(a, b)
        if a.count == b.count then
            return a.class_name < b.class_name
        end
        return a.count > b.count
    end)

    local classes_shown = math.min(#class_list, 12)
    for i = 1, classes_shown do
        local row = class_list[i]
        log(string.format("mesh find class[%d]=%s count=%d", i, row.class_name, row.count))
    end

    log(string.format("mesh find summary total_matches=%d shown=%d classes=%d", total_matches, shown, #class_list))
end

local function set_mesh_filters(parameters)
    local filters = parse_filter_tokens(parameters)

    CONFIG.mesh_name_filters = filters
    normalize_config()

    local shown = table.concat(CONFIG.mesh_name_filters, ",")
    if shown == "" then
        shown = "<none>"
    end

    log(string.format("mesh filters set count=%d values=%s", #CONFIG.mesh_name_filters, shown))
end

local function set_mesh_scope_include_filters(parameters)
    CONFIG.mesh_scope_include_filters = parse_filter_tokens(parameters)
    normalize_config()

    local shown = table.concat(CONFIG.mesh_scope_include_filters, ",")
    if shown == "" then
        shown = "<none>"
    end

    log(string.format("mesh scope include set count=%d values=%s", #CONFIG.mesh_scope_include_filters, shown))
end

local function set_mesh_scope_exclude_filters(parameters)
    CONFIG.mesh_scope_exclude_filters = parse_filter_tokens(parameters)
    normalize_config()

    local shown = table.concat(CONFIG.mesh_scope_exclude_filters, ",")
    if shown == "" then
        shown = "<none>"
    end

    log(string.format("mesh scope exclude set count=%d values=%s", #CONFIG.mesh_scope_exclude_filters, shown))
end

normalize_config = function()
    CONFIG.spot_lights_cast_shadows = CONFIG.spot_lights_cast_shadows == true

    CONFIG.point_lights_cast_shadows = CONFIG.point_lights_cast_shadows == true
    CONFIG.rect_lights_cast_shadows = CONFIG.rect_lights_cast_shadows == true
    CONFIG.generic_lights_cast_shadows = CONFIG.generic_lights_cast_shadows == true
    CONFIG.spotlight_tune_enabled = CONFIG.spotlight_tune_enabled == true
    CONFIG.force_light_movable = CONFIG.force_light_movable == true
    CONFIG.respect_prepatch_shadow_state = CONFIG.respect_prepatch_shadow_state == true
    CONFIG.live_shadow_sync = CONFIG.live_shadow_sync == true
    CONFIG.touch_postprocess_volume = CONFIG.touch_postprocess_volume == true
    CONFIG.force_ppv_enabled = CONFIG.force_ppv_enabled == true
    CONFIG.force_lumen_methods = CONFIG.force_lumen_methods == true
    CONFIG.force_lumen_compatibility = CONFIG.force_lumen_compatibility == true
    CONFIG.lumen_disable_static_lighting = CONFIG.lumen_disable_static_lighting == true
    CONFIG.lumen_force_no_precomputed_lighting = CONFIG.lumen_force_no_precomputed_lighting == true
    CONFIG.lumen_enable_mesh_distance_fields = CONFIG.lumen_enable_mesh_distance_fields == true
    CONFIG.lumen_disable_forward_shading = CONFIG.lumen_disable_forward_shading == true
    CONFIG.skylight_runtime_pass = CONFIG.skylight_runtime_pass == true
    CONFIG.skylight_force_movable = CONFIG.skylight_force_movable == true
    CONFIG.skylight_enable_realtime_capture = CONFIG.skylight_enable_realtime_capture == true
    CONFIG.skylight_recapture_on_patch = CONFIG.skylight_recapture_on_patch == true
    CONFIG.skylight_lower_specular_if_needed = CONFIG.skylight_lower_specular_if_needed == true
    CONFIG.fog_runtime_pass = CONFIG.fog_runtime_pass == true
    CONFIG.fog_enable_exponential_height_fog = CONFIG.fog_enable_exponential_height_fog == true
    CONFIG.fog_enable_volumetric_fog = CONFIG.fog_enable_volumetric_fog == true
    CONFIG.fog_try_lumen_fog_helpers = CONFIG.fog_try_lumen_fog_helpers == true
    CONFIG.distance_fields_verification = CONFIG.distance_fields_verification == true
    CONFIG.distance_fields_log_atlas_on_patch = CONFIG.distance_fields_log_atlas_on_patch == true
    CONFIG.distance_fields_verify_once = CONFIG.distance_fields_verify_once == true
    CONFIG.mesh_runtime_pass = CONFIG.mesh_runtime_pass == true
    CONFIG.mesh_patch_on_refresh = CONFIG.mesh_patch_on_refresh == true
    CONFIG.mesh_reapply_each_refresh = CONFIG.mesh_reapply_each_refresh == true
    CONFIG.mesh_skip_movable = CONFIG.mesh_skip_movable == true
    CONFIG.mesh_include_skeletal_components = CONFIG.mesh_include_skeletal_components == true
    CONFIG.mesh_force_cast_shadow = CONFIG.mesh_force_cast_shadow == true
    CONFIG.mesh_force_dynamic_shadow = CONFIG.mesh_force_dynamic_shadow == true
    CONFIG.mesh_force_static_shadow = CONFIG.mesh_force_static_shadow == true
    CONFIG.mesh_force_two_sided_shadow = CONFIG.mesh_force_two_sided_shadow == true
    CONFIG.mesh_force_affect_distance_field_lighting = CONFIG.mesh_force_affect_distance_field_lighting == true
    CONFIG.mesh_force_visible_in_ray_tracing = CONFIG.mesh_force_visible_in_ray_tracing == true
    CONFIG.mesh_force_component_visible = CONFIG.mesh_force_component_visible == true
    CONFIG.mesh_force_use_as_occluder = CONFIG.mesh_force_use_as_occluder == true
    CONFIG.mesh_force_render_in_main_pass = CONFIG.mesh_force_render_in_main_pass == true
    CONFIG.mesh_force_render_in_depth_pass = CONFIG.mesh_force_render_in_depth_pass == true
    CONFIG.mesh_force_bounds_scale = CONFIG.mesh_force_bounds_scale == true
    CONFIG.mesh_force_never_distance_cull = CONFIG.mesh_force_never_distance_cull == true
    CONFIG.mesh_disable_cull_distance_volume = CONFIG.mesh_disable_cull_distance_volume == true
    CONFIG.mesh_force_zero_max_draw_distance = CONFIG.mesh_force_zero_max_draw_distance == true
    CONFIG.mesh_force_zero_instance_cull_distances = CONFIG.mesh_force_zero_instance_cull_distances == true
    CONFIG.mesh_pseudo_thickness_enabled = CONFIG.mesh_pseudo_thickness_enabled == true
    CONFIG.mesh_force_affect_dynamic_indirect_lighting = CONFIG.mesh_force_affect_dynamic_indirect_lighting == true
    CONFIG.mesh_force_affect_indirect_lighting_while_hidden = CONFIG.mesh_force_affect_indirect_lighting_while_hidden ==
        true
    CONFIG.mesh_force_visible_in_reflection_captures = CONFIG.mesh_force_visible_in_reflection_captures == true
    CONFIG.mesh_force_visible_in_realtime_sky_captures = CONFIG.mesh_force_visible_in_realtime_sky_captures == true
    CONFIG.mesh_invalidate_lumen_surface_cache = CONFIG.mesh_invalidate_lumen_surface_cache == true
    CONFIG.mesh_force_render_state_dirty = CONFIG.mesh_force_render_state_dirty == true
    CONFIG.mesh_pseudo_thickness_require_name_filters = CONFIG.mesh_pseudo_thickness_require_name_filters == true
    CONFIG.mesh_force_distance_field_indirect_shadow = CONFIG.mesh_force_distance_field_indirect_shadow == true
    CONFIG.mesh_fix_black_materials = CONFIG.mesh_fix_black_materials == true
    if type(CONFIG.mesh_force_material_name) ~= "string" then
        CONFIG.mesh_force_material_name = ""
    end
    CONFIG.mesh_force_material_require_name_filters = CONFIG.mesh_force_material_require_name_filters == true
    CONFIG.mesh_disable_world_position_offset = CONFIG.mesh_disable_world_position_offset == true
    CONFIG.mesh_force_generate_mesh_distance_field = CONFIG.mesh_force_generate_mesh_distance_field == true
    CONFIG.autocomplete_enabled = CONFIG.autocomplete_enabled == true
    CONFIG.autocomplete_apply_on_load = CONFIG.autocomplete_apply_on_load == true

    if type(CONFIG.mesh_name_filters) ~= "table" then
        CONFIG.mesh_name_filters = {}
    end
    if type(CONFIG.mesh_scope_include_filters) ~= "table" then
        CONFIG.mesh_scope_include_filters = {}
    end
    if type(CONFIG.mesh_scope_exclude_filters) ~= "table" then
        CONFIG.mesh_scope_exclude_filters = {}
    end
    if type(CONFIG.mesh_scope_autofix_exclude_names) ~= "table" then
        CONFIG.mesh_scope_autofix_exclude_names = {}
    end

    local normalized_mesh_filters = {}
    for _, raw_filter in ipairs(CONFIG.mesh_name_filters) do
        if type(raw_filter) == "string" then
            local trimmed = string.match(raw_filter, "^%s*(.-)%s*$")
            if trimmed ~= nil and trimmed ~= "" then
                normalized_mesh_filters[#normalized_mesh_filters + 1] = trimmed
            end
        end
    end
    CONFIG.mesh_name_filters = normalized_mesh_filters

    local normalized_scope_include_filters = {}
    for _, raw_filter in ipairs(CONFIG.mesh_scope_include_filters) do
        if type(raw_filter) == "string" then
            local trimmed = string.match(raw_filter, "^%s*(.-)%s*$")
            if trimmed ~= nil and trimmed ~= "" then
                normalized_scope_include_filters[#normalized_scope_include_filters + 1] = trimmed
            end
        end
    end
    CONFIG.mesh_scope_include_filters = normalized_scope_include_filters

    local normalized_scope_exclude_filters = {}
    for _, raw_filter in ipairs(CONFIG.mesh_scope_exclude_filters) do
        if type(raw_filter) == "string" then
            local trimmed = string.match(raw_filter, "^%s*(.-)%s*$")
            if trimmed ~= nil and trimmed ~= "" then
                normalized_scope_exclude_filters[#normalized_scope_exclude_filters + 1] = trimmed
            end
        end
    end
    CONFIG.mesh_scope_exclude_filters = normalized_scope_exclude_filters

    local normalized_scope_exclude_names = {}
    for _, raw_filter in ipairs(CONFIG.mesh_scope_autofix_exclude_names) do
        if type(raw_filter) == "string" then
            local trimmed = string.match(raw_filter, "^%s*(.-)%s*$")
            if trimmed ~= nil and trimmed ~= "" then
                normalized_scope_exclude_names[#normalized_scope_exclude_names + 1] = trimmed
            end
        end
    end
    CONFIG.mesh_scope_autofix_exclude_names = normalized_scope_exclude_names

    if type(CONFIG.mesh_bounds_scale) ~= "number" then
        CONFIG.mesh_bounds_scale = 2.0
    end
    CONFIG.mesh_bounds_scale = math.max(1.0, CONFIG.mesh_bounds_scale)

    CONFIG.mesh_pseudo_thickness_axis = normalize_axis_name(CONFIG.mesh_pseudo_thickness_axis)

    if type(CONFIG.mesh_pseudo_thickness_multiplier) ~= "number" then
        CONFIG.mesh_pseudo_thickness_multiplier = 1.15
    end
    CONFIG.mesh_pseudo_thickness_multiplier = math.max(1.0, CONFIG.mesh_pseudo_thickness_multiplier)

    if type(CONFIG.mesh_find_default_query) ~= "string" then
        CONFIG.mesh_find_default_query = "wall"
    end
    CONFIG.mesh_find_default_query = trim(CONFIG.mesh_find_default_query)

    if type(CONFIG.mesh_find_default_limit) ~= "number" then
        CONFIG.mesh_find_default_limit = 40
    end
    CONFIG.mesh_find_default_limit = math.max(1, math.floor(CONFIG.mesh_find_default_limit))

    if type(CONFIG.spotlight_tune_mode) ~= "string" then
        CONFIG.spotlight_tune_mode = "multiplier"
    end
    local tune_mode = string.lower(CONFIG.spotlight_tune_mode)
    if tune_mode ~= "absolute" and tune_mode ~= "multiplier" then
        tune_mode = "multiplier"
    end
    CONFIG.spotlight_tune_mode = tune_mode

    if type(CONFIG.lumen_gi_method_value) ~= "number" then
        CONFIG.lumen_gi_method_value = 1
    end
    CONFIG.lumen_gi_method_value = math.max(0, math.floor(CONFIG.lumen_gi_method_value))

    if type(CONFIG.lumen_reflection_method_value) ~= "number" then
        CONFIG.lumen_reflection_method_value = 1
    end
    CONFIG.lumen_reflection_method_value = math.max(0, math.floor(CONFIG.lumen_reflection_method_value))

    if type(CONFIG.lumen_scene_detail) ~= "number" then
        CONFIG.lumen_scene_detail = 2.8
    end

    if type(CONFIG.lumen_diffuse_color_boost) ~= "number" then
        CONFIG.lumen_diffuse_color_boost = 1.5
    end

    if type(CONFIG.lumen_skylight_leaking) ~= "number" then
        CONFIG.lumen_skylight_leaking = 0.050
    end

    if type(CONFIG.lumen_max_trace_distance) ~= "number" then
        CONFIG.lumen_max_trace_distance = 200000
    end

    if type(CONFIG.skylight_recapture_interval_ms) ~= "number" then
        CONFIG.skylight_recapture_interval_ms = 0
    end
    CONFIG.skylight_recapture_interval_ms = math.max(0, math.floor(CONFIG.skylight_recapture_interval_ms))

    if type(CONFIG.skylight_intensity_multiplier) ~= "number" then
        CONFIG.skylight_intensity_multiplier = 1.0
    end
    CONFIG.skylight_intensity_multiplier = math.max(0.0, CONFIG.skylight_intensity_multiplier)

    if type(CONFIG.skylight_indirect_multiplier) ~= "number" then
        CONFIG.skylight_indirect_multiplier = 1.0
    end
    CONFIG.skylight_indirect_multiplier = math.max(0.0, CONFIG.skylight_indirect_multiplier)

    if type(CONFIG.distance_fields_log_atlas_interval_ms) ~= "number" then
        CONFIG.distance_fields_log_atlas_interval_ms = 0
    end
    CONFIG.distance_fields_log_atlas_interval_ms = math.max(0, math.floor(CONFIG.distance_fields_log_atlas_interval_ms))

    if (type(CONFIG.spotlight_intensity_multiplier) ~= "number" or CONFIG.spotlight_intensity_multiplier < 0.0) and type(CONFIG.spotlight_intensity_scale) == "number" then
        CONFIG.spotlight_intensity_multiplier = CONFIG.spotlight_intensity_scale
    end
    if (type(CONFIG.spotlight_indirect_lighting_multiplier) ~= "number" or CONFIG.spotlight_indirect_lighting_multiplier < 0.0) and type(CONFIG.spotlight_indirect_scale) == "number" then
        CONFIG.spotlight_indirect_lighting_multiplier = CONFIG.spotlight_indirect_scale
    end
    if CONFIG.spotlight_outer_cone_angle == -1.0 and type(CONFIG.spotlight_min_outer_cone) == "number" then
        CONFIG.spotlight_outer_cone_angle = CONFIG.spotlight_min_outer_cone
    end
    if CONFIG.spotlight_source_radius == -1.0 and type(CONFIG.spotlight_min_source_radius) == "number" then
        CONFIG.spotlight_source_radius = CONFIG.spotlight_min_source_radius
    end
    if CONFIG.spotlight_soft_source_radius == -1.0 and type(CONFIG.spotlight_min_soft_source_radius) == "number" then
        CONFIG.spotlight_soft_source_radius = CONFIG.spotlight_min_soft_source_radius
    end
    if CONFIG.spotlight_source_length == -1.0 and type(CONFIG.spotlight_min_source_length) == "number" then
        CONFIG.spotlight_source_length = CONFIG.spotlight_min_source_length
    end

    if type(CONFIG.spotlight_intensity) ~= "number" then
        CONFIG.spotlight_intensity = -1.0
    end
    if CONFIG.spotlight_intensity < 0.0 then
        CONFIG.spotlight_intensity = -1.0
    end

    if type(CONFIG.spotlight_indirect_lighting_intensity) ~= "number" then
        CONFIG.spotlight_indirect_lighting_intensity = -1.0
    end
    if CONFIG.spotlight_indirect_lighting_intensity < 0.0 then
        CONFIG.spotlight_indirect_lighting_intensity = -1.0
    end

    if type(CONFIG.spotlight_specular_scale) ~= "number" then
        CONFIG.spotlight_specular_scale = -1.0
    end
    if CONFIG.spotlight_specular_scale < 0.0 then
        CONFIG.spotlight_specular_scale = -1.0
    end

    if type(CONFIG.spotlight_attenuation_radius) ~= "number" then
        CONFIG.spotlight_attenuation_radius = -1.0
    end
    if CONFIG.spotlight_attenuation_radius < 0.0 then
        CONFIG.spotlight_attenuation_radius = -1.0
    end

    if type(CONFIG.spotlight_outer_cone_angle) ~= "number" then
        CONFIG.spotlight_outer_cone_angle = -1.0
    end
    if CONFIG.spotlight_outer_cone_angle < 0.0 then
        CONFIG.spotlight_outer_cone_angle = -1.0
    end

    if type(CONFIG.spotlight_inner_cone_angle) ~= "number" then
        CONFIG.spotlight_inner_cone_angle = -1.0
    end
    if CONFIG.spotlight_inner_cone_angle < 0.0 then
        CONFIG.spotlight_inner_cone_angle = -1.0
    end

    if type(CONFIG.spotlight_source_radius) ~= "number" then
        CONFIG.spotlight_source_radius = -1.0
    end
    if CONFIG.spotlight_source_radius < 0.0 then
        CONFIG.spotlight_source_radius = -1.0
    end

    if type(CONFIG.spotlight_soft_source_radius) ~= "number" then
        CONFIG.spotlight_soft_source_radius = -1.0
    end
    if CONFIG.spotlight_soft_source_radius < 0.0 then
        CONFIG.spotlight_soft_source_radius = -1.0
    end

    if type(CONFIG.spotlight_source_length) ~= "number" then
        CONFIG.spotlight_source_length = -1.0
    end
    if CONFIG.spotlight_source_length < 0.0 then
        CONFIG.spotlight_source_length = -1.0
    end

    if type(CONFIG.spotlight_intensity_multiplier) ~= "number" then
        CONFIG.spotlight_intensity_multiplier = -1.0
    end
    if CONFIG.spotlight_intensity_multiplier < 0.0 then
        CONFIG.spotlight_intensity_multiplier = -1.0
    end

    if type(CONFIG.spotlight_indirect_lighting_multiplier) ~= "number" then
        CONFIG.spotlight_indirect_lighting_multiplier = -1.0
    end
    if CONFIG.spotlight_indirect_lighting_multiplier < 0.0 then
        CONFIG.spotlight_indirect_lighting_multiplier = -1.0
    end

    if type(CONFIG.spotlight_specular_multiplier) ~= "number" then
        CONFIG.spotlight_specular_multiplier = -1.0
    end
    if CONFIG.spotlight_specular_multiplier < 0.0 then
        CONFIG.spotlight_specular_multiplier = -1.0
    end

    if type(CONFIG.spotlight_attenuation_multiplier) ~= "number" then
        CONFIG.spotlight_attenuation_multiplier = -1.0
    end
    if CONFIG.spotlight_attenuation_multiplier < 0.0 then
        CONFIG.spotlight_attenuation_multiplier = -1.0
    end

    if type(CONFIG.spotlight_outer_cone_multiplier) ~= "number" then
        CONFIG.spotlight_outer_cone_multiplier = -1.0
    end
    if CONFIG.spotlight_outer_cone_multiplier < 0.0 then
        CONFIG.spotlight_outer_cone_multiplier = -1.0
    end

    if type(CONFIG.spotlight_inner_cone_multiplier) ~= "number" then
        CONFIG.spotlight_inner_cone_multiplier = -1.0
    end
    if CONFIG.spotlight_inner_cone_multiplier < 0.0 then
        CONFIG.spotlight_inner_cone_multiplier = -1.0
    end

    if type(CONFIG.spotlight_source_radius_multiplier) ~= "number" then
        CONFIG.spotlight_source_radius_multiplier = -1.0
    end
    if CONFIG.spotlight_source_radius_multiplier < 0.0 then
        CONFIG.spotlight_source_radius_multiplier = -1.0
    end

    if type(CONFIG.spotlight_soft_source_radius_multiplier) ~= "number" then
        CONFIG.spotlight_soft_source_radius_multiplier = -1.0
    end
    if CONFIG.spotlight_soft_source_radius_multiplier < 0.0 then
        CONFIG.spotlight_soft_source_radius_multiplier = -1.0
    end

    if type(CONFIG.spotlight_source_length_multiplier) ~= "number" then
        CONFIG.spotlight_source_length_multiplier = -1.0
    end
    if CONFIG.spotlight_source_length_multiplier < 0.0 then
        CONFIG.spotlight_source_length_multiplier = -1.0
    end

    if type(CONFIG.shadow_tick_ms) ~= "number" then
        CONFIG.shadow_tick_ms = 250
    end
    CONFIG.shadow_tick_ms = math.max(100, math.floor(CONFIG.shadow_tick_ms))

    if type(CONFIG.cache_refresh_ms) ~= "number" then
        CONFIG.cache_refresh_ms = 1000
    end
    CONFIG.cache_refresh_ms = math.max(CONFIG.shadow_tick_ms, math.floor(CONFIG.cache_refresh_ms))

    if type(CONFIG.autocomplete_dump_path) ~= "string" or CONFIG.autocomplete_dump_path == "" then
        CONFIG.autocomplete_dump_path = "D:/Games/BetterMart/BetterMart/Binaries/Win64/UUU_CVarsDump.json"
    end
    CONFIG.autocomplete_dump_path = normalize_dump_path(CONFIG.autocomplete_dump_path)

    if type(CONFIG.autocomplete_input_ini_path) ~= "string" then
        CONFIG.autocomplete_input_ini_path = ""
    end
    CONFIG.autocomplete_input_ini_path = normalize_dump_path(CONFIG.autocomplete_input_ini_path)

    if type(CONFIG.autocomplete_max_entries) ~= "number" then
        CONFIG.autocomplete_max_entries = 10000
    end
    CONFIG.autocomplete_max_entries = math.max(1, math.floor(CONFIG.autocomplete_max_entries))
end

local function register_commands()
    if type(RegisterConsoleCommandGlobalHandler) ~= "function" then
        log("console handler unavailable")
        return
    end

    RegisterConsoleCommandGlobalHandler("tajsgraph.apply", function(_, _)
        run_apply()
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.patch", function(_, _)
        run_apply()
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.status", function(_, _)
        run_status()
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.prepatch", function(_, _)
        run_prepatch_dump()
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.rebaseline", function(_, _)
        reset_spotlight_baselines()
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.skylight_refresh", function(_, _)
        maybe_patch_skylights(true)
        log(string.format("sky refresh recapture_ok=%d/%d write_fail=%d", STATE.skylight_recapture_ok,
            STATE.skylight_recapture_attempted, STATE.skylight_write_fail))
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.df_verify", function(_, _)
        maybe_verify_distance_fields(true)
        log(string.format("df verify runs=%d atlas_req=%d scan=%d flags=%d skip=%s", STATE.df_verify_runs,
            STATE.df_atlas_log_requests, STATE.df_component_scan_count, STATE.df_components_with_df_flags,
            tostring(STATE.df_verify_skipped_reason)))
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.fog_patch", function(_, _)
        maybe_patch_fog(true)
        log(string.format("fog patch found=%d valid=%d enabled=%d volumetric=%d write_fail=%d", STATE.fog_actors_found,
            STATE.fog_valid, STATE.fog_enabled, STATE.fog_volumetric_enabled, STATE.fog_write_fail))
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.skylight_status", function(_, _)
        log(string.format(
            "sky status found=%d valid=%d patched=%d movable=%d realtime=%d recapture_ok=%d/%d scale_int=%d scale_ind=%d write_fail=%d",
            STATE.skylight_found, STATE.skylight_valid, STATE.skylight_patched, STATE.skylight_movable_forced,
            STATE.skylight_realtime_enabled, STATE.skylight_recapture_ok, STATE.skylight_recapture_attempted,
            STATE.skylight_intensity_scaled, STATE.skylight_indirect_scaled, STATE.skylight_write_fail))
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.mesh_patch", function(_, _)
        normalize_config()
        if not CONFIG.mesh_runtime_pass then
            log("mesh patch skipped: mesh_runtime_pass=false")
            return true
        end

        refresh_mesh_cache()
        patch_cached_mesh_components(true)
        local level_name = get_current_level_name() or ""
        log(string.format(
            "mesh patch level=%s found=%d candidates=%d foliage_found=%d foliage_candidates=%d skeletal_found=%d skeletal_candidates=%d ism_found=%d ism_candidates=%d hism_found=%d hism_candidates=%d patched_total=%d patched_now=%d apply_ops=%d write_fail=%d filtered_out=%d scope_filtered=%d cull_ops=%d cull_fail=%d bounds_ops=%d bounds_fail=%d thick_ops=%d thick_fail=%d lumen_cache=%d/%d render_state=%d/%d",
            tostring(level_name), STATE.mesh_components_found, STATE.mesh_components_candidates,
            STATE.mesh_foliage_components_found, STATE.mesh_foliage_components_candidates,
            STATE.mesh_skeletal_components_found, STATE.mesh_skeletal_components_candidates,
            STATE.mesh_ism_components_found, STATE.mesh_ism_components_candidates, STATE.mesh_hism_components_found,
            STATE.mesh_hism_components_candidates, STATE.mesh_components_patched_total,
            STATE.mesh_components_patched_last, STATE.mesh_force_apply_ops_last, STATE.mesh_write_fail_last,
            STATE.mesh_filter_skipped_last, STATE.mesh_scope_skipped_last, STATE.mesh_cull_distance_ops_last,
            STATE.mesh_cull_distance_fail_last, STATE.mesh_bounds_scale_ops_last, STATE.mesh_bounds_scale_fail_last,
            STATE.mesh_pseudo_thickness_ops_last, STATE.mesh_pseudo_thickness_fail_last,
            STATE.mesh_lumen_cache_invalidations_last, STATE.mesh_lumen_cache_invalidation_fail_last,
            STATE.mesh_render_state_dirty_last, STATE.mesh_render_state_dirty_fail_last))
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.mesh_status", function(_, _)
        normalize_config()
        refresh_mesh_cache()
        local level_name = get_current_level_name() or ""
        log(string.format(
            "mesh status level=%s pass=%s refresh_patch=%s reapply=%s skip_movable=%s include_skeletal=%s filters=%d scope_include=%d scope_exclude=%d bounds_force=%s bounds_scale=%.3f never_cull=%s cull_vol_off=%s max_draw_zero=%s instance_cull_zero=%s pseudo_thickness=%s axis=%s thick_mul=%.3f found=%d candidates=%d foliage_found=%d foliage_candidates=%d skeletal_found=%d skeletal_candidates=%d ism_found=%d ism_candidates=%d hism_found=%d hism_candidates=%d patched_total=%d patched_last=%d apply_ops=%d write_fail=%d filtered_out=%d scope_filtered=%d cull_ops=%d cull_fail=%d bounds_ops=%d bounds_fail=%d thick_ops=%d thick_fail=%d lumen_cache=%d/%d render_state=%d/%d",
            tostring(level_name), tostring(CONFIG.mesh_runtime_pass), tostring(CONFIG.mesh_patch_on_refresh),
            tostring(CONFIG.mesh_reapply_each_refresh), tostring(CONFIG.mesh_skip_movable),
            tostring(CONFIG.mesh_include_skeletal_components),
            (type(CONFIG.mesh_name_filters) == "table" and #CONFIG.mesh_name_filters or 0),
            (type(CONFIG.mesh_scope_include_filters) == "table" and #CONFIG.mesh_scope_include_filters or 0),
            (type(CONFIG.mesh_scope_exclude_filters) == "table" and #CONFIG.mesh_scope_exclude_filters or 0),
            tostring(CONFIG.mesh_force_bounds_scale), CONFIG.mesh_bounds_scale,
            tostring(CONFIG.mesh_force_never_distance_cull), tostring(CONFIG.mesh_disable_cull_distance_volume),
            tostring(CONFIG.mesh_force_zero_max_draw_distance), tostring(CONFIG.mesh_force_zero_instance_cull_distances),
            tostring(CONFIG.mesh_pseudo_thickness_enabled), tostring(CONFIG.mesh_pseudo_thickness_axis),
            CONFIG.mesh_pseudo_thickness_multiplier, STATE.mesh_components_found, STATE.mesh_components_candidates,
            STATE.mesh_foliage_components_found, STATE.mesh_foliage_components_candidates,
            STATE.mesh_skeletal_components_found, STATE.mesh_skeletal_components_candidates,
            STATE.mesh_ism_components_found, STATE.mesh_ism_components_candidates, STATE.mesh_hism_components_found,
            STATE.mesh_hism_components_candidates, STATE.mesh_components_patched_total,
            STATE.mesh_components_patched_last, STATE.mesh_force_apply_ops_last, STATE.mesh_write_fail_last,
            STATE.mesh_filter_skipped_last, STATE.mesh_scope_skipped_last, STATE.mesh_cull_distance_ops_last,
            STATE.mesh_cull_distance_fail_last, STATE.mesh_bounds_scale_ops_last, STATE.mesh_bounds_scale_fail_last,
            STATE.mesh_pseudo_thickness_ops_last, STATE.mesh_pseudo_thickness_fail_last,
            STATE.mesh_lumen_cache_invalidations_last, STATE.mesh_lumen_cache_invalidation_fail_last,
            STATE.mesh_render_state_dirty_last, STATE.mesh_render_state_dirty_fail_last))
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.mesh_find", function(_, parameters)
        run_mesh_find(parameters)
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.mesh_filter_set", function(_, parameters)
        set_mesh_filters(parameters)
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.mesh_filter_clear", function(_, _)
        CONFIG.mesh_name_filters = {}
        normalize_config()
        log("mesh filters cleared")
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.mesh_scope_include_set", function(_, parameters)
        set_mesh_scope_include_filters(parameters)
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.mesh_scope_exclude_set", function(_, parameters)
        set_mesh_scope_exclude_filters(parameters)
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.mesh_scope_clear", function(_, _)
        CONFIG.mesh_scope_include_filters = {}
        CONFIG.mesh_scope_exclude_filters = {}
        normalize_config()
        log("mesh scope filters cleared")
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.mesh_force_material", function(_, parameters)
        if type(parameters) ~= "table" or #parameters == 0 then
            CONFIG.mesh_force_material_name = ""
        else
            CONFIG.mesh_force_material_name = tostring(parameters[1])
        end
        normalize_config()
        log(string.format("mesh force material name=%s", CONFIG.mesh_force_material_name))
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.mesh_force_mesh_distance_field", function(_, parameters)
        if type(parameters) ~= "table" or #parameters == 0 then
            CONFIG.mesh_force_generate_mesh_distance_field = true
        else
            local value = tostring(parameters[1])
            CONFIG.mesh_force_generate_mesh_distance_field = value == "true" or value == "1" or value == "on"
        end
        normalize_config()
        log(string.format("mesh force generate mesh distance field=%s",
            tostring(CONFIG.mesh_force_generate_mesh_distance_field)))
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.mesh_scope_autofix", function(_, _)
        refresh_mesh_cache()

        local level_name = get_current_level_name()
        if type(level_name) ~= "string" or level_name == "" or is_autofix_level_excluded(level_name) then
            level_name = nil
        end

        local fallback_name, fallback_count = get_best_level_name_from_mesh_entries()
        local chosen = level_name or fallback_name
        if type(chosen) ~= "string" or chosen == "" then
            log("mesh scope autofix: current level name unavailable")
            return true
        end

        local normalized = string.lower(chosen)
        CONFIG.mesh_scope_include_filters = { normalized }
        normalize_config()
        log(string.format("mesh scope autofix: level='%s' include=%s source=%s count=%d", tostring(chosen), normalized,
            level_name and "current" or "mesh_entries", tonumber(fallback_count or 0)))
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.autocomplete_apply", function(_, _)
        run_autocomplete_apply()
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.autocomplete_reload", function(_, _)
        run_autocomplete_reload()
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.autocomplete_status", function(_, _)
        run_autocomplete_status()
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.autocomplete_probe", function(_, _)
        run_autocomplete_probe()
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.autocomplete_export_inputini", function(_, _)
        export_autocomplete_to_input_ini()
        return true
    end)

    RegisterConsoleCommandGlobalHandler("tajsgraph.autocomplete_suggest", function(_, parameters)
        run_autocomplete_suggest(parameters)
        return true
    end)
end

normalize_config()
register_commands()
if CONFIG.autocomplete_apply_on_load then
    run_autocomplete_reload()
end
log("loaded (unified lights + renderer/ppv megalights)")
