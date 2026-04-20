local log_mod = require("rt_log")
local obj_mod = require("rt_object")

local M = {
    __tajsgraph_module = "rt_spotlight"
}

local EPSILON = 0.0001

local TUNABLE_FIELDS = {
    "Intensity",
    "IndirectLightingIntensity",
    "SpecularScale",
    "AttenuationRadius",
    "OuterConeAngle",
    "InnerConeAngle",
    "SourceRadius",
    "SoftSourceRadius",
    "SourceLength",
}

local FIELD_TO_ABSOLUTE = {
    Intensity = "spotlight_intensity",
    IndirectLightingIntensity = "spotlight_indirect_lighting_intensity",
    SpecularScale = "spotlight_specular_scale",
    AttenuationRadius = "spotlight_attenuation_radius",
    OuterConeAngle = "spotlight_outer_cone_angle",
    InnerConeAngle = "spotlight_inner_cone_angle",
    SourceRadius = "spotlight_source_radius",
    SoftSourceRadius = "spotlight_soft_source_radius",
    SourceLength = "spotlight_source_length",
}

local FIELD_TO_MULTIPLIER = {
    Intensity = "spotlight_intensity_multiplier",
    IndirectLightingIntensity = "spotlight_indirect_lighting_multiplier",
    SpecularScale = "spotlight_specular_multiplier",
    AttenuationRadius = "spotlight_attenuation_multiplier",
    OuterConeAngle = "spotlight_outer_cone_multiplier",
    InnerConeAngle = "spotlight_inner_cone_multiplier",
    SourceRadius = "spotlight_source_radius_multiplier",
    SoftSourceRadius = "spotlight_soft_source_radius_multiplier",
    SourceLength = "spotlight_source_length_multiplier",
}

local FIELD_TO_SETTER = {
    Intensity = "SetIntensity",
    IndirectLightingIntensity = "SetIndirectLightingIntensity",
    SpecularScale = "SetSpecularScale",
    AttenuationRadius = "SetAttenuationRadius",
    OuterConeAngle = "SetOuterConeAngle",
    InnerConeAngle = "SetInnerConeAngle",
    SourceRadius = "SetSourceRadius",
    SoftSourceRadius = "SetSoftSourceRadius",
    SourceLength = "SetSourceLength",
}

local safe_call = log_mod.safe_call

local function copy_snapshot(snapshot)
    if type(snapshot) ~= "table" then
        return nil
    end

    local result = {}
    for key, value in pairs(snapshot) do
        result[key] = value
    end
    return result
end

local function nearly_equal(a, b)
    return math.abs(a - b) <= EPSILON
end

local function write_bool_if_needed(light, field, target, setter_name, force_write)
    local ok_current, current = obj_mod.read_bool_property(light, field)
    if (not force_write) and ok_current and current == target then
        return false
    end

    if type(setter_name) == "string" and setter_name ~= "" then
        if obj_mod.call_method_if_valid(light, setter_name, target) then
            return true
        end
    end

    return obj_mod.safe_set(light, field, target)
end

local function write_number_if_needed(light, field, target, setter_name, force_write)
    local ok_current, current = obj_mod.read_numeric_property(light, field)
    if (not force_write) and ok_current and nearly_equal(current, target) then
        return false
    end

    return obj_mod.set_number_with_setter(light, field, target, setter_name)
end

local function capture_snapshot(light)
    local snapshot = {}
    for _, field in ipairs(TUNABLE_FIELDS) do
        local ok, value = obj_mod.read_numeric_property(light, field)
        if ok then
            snapshot[field] = value
        end
    end

    local ok_affects_world, affects_world = obj_mod.read_bool_property(light, "bAffectsWorld")
    if ok_affects_world then
        snapshot.bAffectsWorld = affects_world
    end

    local ok_visible, visible = obj_mod.read_bool_property(light, "bVisible")
    if ok_visible then
        snapshot.bVisible = visible
    end

    local ok_enabled, enabled = obj_mod.read_bool_property(light, "bEnabled")
    if ok_enabled then
        snapshot.bEnabled = enabled
    end

    local ok_cast, cast_shadows = obj_mod.read_bool_property(light, "CastShadows")
    if ok_cast then
        snapshot.CastShadows = cast_shadows
    end

    local ok_mobility, mobility = obj_mod.read_mobility_property(light)
    if ok_mobility then
        snapshot.Mobility = mobility
    end

    return snapshot
end

local function compute_target(config, entry, field)
    local baseline_value = entry.baseline and entry.baseline[field] or nil
    if type(baseline_value) ~= "number" then
        return nil
    end

    if config.spotlight_tune_mode == "absolute" then
        local absolute_key = FIELD_TO_ABSOLUTE[field]
        local absolute_value = config[absolute_key]
        if type(absolute_value) == "number" and absolute_value >= 0 then
            return absolute_value
        end
        return baseline_value
    end

    local multiplier_key = FIELD_TO_MULTIPLIER[field]
    local multiplier_value = config[multiplier_key]
    if type(multiplier_value) ~= "number" then
        multiplier_value = 1.0
    end

    return baseline_value * multiplier_value
end

local function upsert_light(state, light)
    if not obj_mod.is_valid_object(light) then
        return nil
    end

    local key = obj_mod.object_key(light)
    local entry = state.light_entries[key]
    if entry == nil then
        entry = {
            key = key,
            obj = light,
            baseline = nil,
            original_snapshot = nil,
            last_applied = {},
            seen_cycle = state.apply_cycle,
        }
        state.light_entries[key] = entry
    else
        entry.obj = light
        entry.seen_cycle = state.apply_cycle
    end

    return entry
end

local function apply_entry(state, config, entry, force_refresh)
    local light = entry.obj
    if not obj_mod.is_valid_object(light) then
        return false
    end

    if state.disabled == true then
        return true
    end

    if entry.baseline == nil then
        -- Baseline is captured once for idempotent multiplier reapply.
        entry.baseline = capture_snapshot(light)
        if entry.original_snapshot == nil then
            entry.original_snapshot = copy_snapshot(entry.baseline)
        end
    elseif entry.original_snapshot == nil then
        entry.original_snapshot = copy_snapshot(entry.baseline)
    end

    local should_tune = config.spotlight_tune_enabled == true
    local s = state.stats
    local entry_changed = false

    if config.spotlight_runtime_compat_enabled then
        if config.spotlight_runtime_force_visible_enabled then
            local visibility_changed = false
            if write_bool_if_needed(light, "bAffectsWorld", true, nil, force_refresh) then
                visibility_changed = true
            end
            if write_bool_if_needed(light, "bVisible", true, "SetVisibility", force_refresh) then
                visibility_changed = true
            end
            if write_bool_if_needed(light, "bEnabled", true, nil, force_refresh) then
                visibility_changed = true
            end
            if visibility_changed then
                entry_changed = true
            end
        end

        if config.spotlight_runtime_force_cast_shadows then
            if write_bool_if_needed(light, "CastShadows", true, "SetCastShadows", force_refresh) then
                entry_changed = true
            end
        end

        if config.spotlight_runtime_force_movable then
            local target_mobility = config.spotlight_runtime_mobility_value
            local before_ok, before_mobility = obj_mod.read_mobility_property(light)
            local wrote_mobility = false

            if force_refresh or (not before_ok) or before_mobility ~= target_mobility then
                if obj_mod.call_method_if_valid(light, "SetMobility", target_mobility) then
                    wrote_mobility = true
                end
                if obj_mod.safe_set(light, "Mobility", target_mobility) then
                    wrote_mobility = true
                end
                if obj_mod.safe_set(light, "MobilityPrivate", target_mobility) then
                    wrote_mobility = true
                end
            end

            local after_ok, after_mobility = obj_mod.read_mobility_property(light)
            if after_ok and after_mobility == target_mobility then
                if wrote_mobility then
                    entry_changed = true
                end
            else
                if wrote_mobility then
                    s.mobility_fail_last = s.mobility_fail_last + 1
                    s.mobility_fail_total = s.mobility_fail_total + 1
                end
            end
        end
    end

    if should_tune then
        for _, field in ipairs(TUNABLE_FIELDS) do
            local target = compute_target(config, entry, field)
            if type(target) == "number" then
                s.spot_attempted_last = s.spot_attempted_last + 1
                s.spot_attempted_total = s.spot_attempted_total + 1

                local ok_current, current = obj_mod.read_numeric_property(light, field)
                if not ok_current then
                    s.spot_failed_last = s.spot_failed_last + 1
                    s.spot_failed_total = s.spot_failed_total + 1
                else
                    if (not nearly_equal(current, target)) or force_refresh then
                        local ok_write = obj_mod.set_number_with_setter(light, field, target, FIELD_TO_SETTER[field])
                        if ok_write then
                            entry.last_applied[field] = target
                            if not nearly_equal(current, target) then
                                s.spot_changed_last = s.spot_changed_last + 1
                                s.spot_changed_total = s.spot_changed_total + 1
                            end
                            entry_changed = true
                        else
                            s.spot_failed_last = s.spot_failed_last + 1
                            s.spot_failed_total = s.spot_failed_total + 1
                        end
                    else
                        entry.last_applied[field] = target
                    end
                end
            end
        end
    end

    local ok_inner, inner_value = obj_mod.read_numeric_property(light, "InnerConeAngle")
    local ok_outer, outer_value = obj_mod.read_numeric_property(light, "OuterConeAngle")
    if ok_inner and ok_outer and inner_value > outer_value then
        local ok_fix = obj_mod.set_number_with_setter(light, "InnerConeAngle", outer_value,
            FIELD_TO_SETTER.InnerConeAngle)
        if ok_fix then
            entry_changed = true
        end
    end

    if entry_changed then
        -- Keep render state coherent after runtime edits.
        obj_mod.call_method_if_valid(light, "MarkRenderStateDirty")
        s.lights_patched_last = s.lights_patched_last + 1
        s.lights_patched_total = s.lights_patched_total + 1
    end

    return true
end

function M.discover_spotlights(state)
    local found = 0
    local list = nil

    local ok_find, result = safe_call(function()
        if type(FindAllOf) == "function" then
            return FindAllOf("SpotLightComponent")
        end
        return nil
    end)

    if ok_find and type(result) == "table" then
        list = result
    else
        list = {}
    end

    for _, light in ipairs(list) do
        local entry = upsert_light(state, light)
        if entry ~= nil then
            found = found + 1
        end
    end

    state.stats.lights_found = found
end

function M.apply_spotlights(state, config, force_refresh)
    for _, entry in pairs(state.light_entries) do
        apply_entry(state, config, entry, force_refresh == true)
    end
end

function M.apply_spawned_spotlight(state, config, light)
    local entry = upsert_light(state, light)
    if entry == nil then
        return false
    end

    apply_entry(state, config, entry, false)
    M.prune_spotlight_cache(state)
    return true
end

function M.rebaseline_spotlights(state)
    local updated = 0
    for _, entry in pairs(state.light_entries) do
        if obj_mod.is_valid_object(entry.obj) then
            entry.baseline = capture_snapshot(entry.obj)
            entry.last_applied = {}
            updated = updated + 1
        end
    end
    return updated
end

function M.restore_spotlights(state, detail_logger)
    local summary = {
        attempted = 0,
        restored = 0,
        skipped = 0,
        failed = 0,
        properties_restored = 0,
        properties_skipped = 0,
        properties_failed = 0,
    }

    for _, entry in pairs(state.light_entries) do
        local light = entry.obj
        summary.attempted = summary.attempted + 1

        if not obj_mod.is_valid_object(light) then
            summary.skipped = summary.skipped + 1
            if type(detail_logger) == "function" then
                detail_logger("skip invalid spotlight", entry.key)
            end
            goto continue
        end

        local snapshot = entry.original_snapshot
        if type(snapshot) ~= "table" then
            summary.skipped = summary.skipped + 1
            if type(detail_logger) == "function" then
                detail_logger("skip missing original snapshot", entry.key)
            end
            goto continue
        end

        local entry_failures = 0
        local entry_changes = 0

        for _, field in ipairs(TUNABLE_FIELDS) do
            local target = snapshot[field]
            if type(target) == "number" then
                local ok_write = obj_mod.set_number_with_setter(light, field, target, FIELD_TO_SETTER[field])
                if ok_write then
                    summary.properties_restored = summary.properties_restored + 1
                    entry_changes = entry_changes + 1
                else
                    summary.properties_failed = summary.properties_failed + 1
                    entry_failures = entry_failures + 1
                end
            else
                summary.properties_skipped = summary.properties_skipped + 1
            end
        end

        if type(snapshot.bAffectsWorld) == "boolean" then
            if write_bool_if_needed(light, "bAffectsWorld", snapshot.bAffectsWorld, nil, true) then
                summary.properties_restored = summary.properties_restored + 1
                entry_changes = entry_changes + 1
            else
                summary.properties_failed = summary.properties_failed + 1
                entry_failures = entry_failures + 1
            end
        end

        if type(snapshot.bVisible) == "boolean" then
            if write_bool_if_needed(light, "bVisible", snapshot.bVisible, "SetVisibility", true) then
                summary.properties_restored = summary.properties_restored + 1
                entry_changes = entry_changes + 1
            else
                summary.properties_failed = summary.properties_failed + 1
                entry_failures = entry_failures + 1
            end
        end

        if type(snapshot.bEnabled) == "boolean" then
            if write_bool_if_needed(light, "bEnabled", snapshot.bEnabled, nil, true) then
                summary.properties_restored = summary.properties_restored + 1
                entry_changes = entry_changes + 1
            else
                summary.properties_failed = summary.properties_failed + 1
                entry_failures = entry_failures + 1
            end
        end

        if type(snapshot.CastShadows) == "boolean" then
            if write_bool_if_needed(light, "CastShadows", snapshot.CastShadows, "SetCastShadows", true) then
                summary.properties_restored = summary.properties_restored + 1
                entry_changes = entry_changes + 1
            else
                summary.properties_failed = summary.properties_failed + 1
                entry_failures = entry_failures + 1
            end
        end

        if type(snapshot.Mobility) == "number" then
            local target_mobility = math.floor(snapshot.Mobility)
            local wrote_mobility = false
            if obj_mod.call_method_if_valid(light, "SetMobility", target_mobility) then
                wrote_mobility = true
            end
            if obj_mod.safe_set(light, "Mobility", target_mobility) then
                wrote_mobility = true
            end
            if obj_mod.safe_set(light, "MobilityPrivate", target_mobility) then
                wrote_mobility = true
            end
            if wrote_mobility then
                summary.properties_restored = summary.properties_restored + 1
                entry_changes = entry_changes + 1
            else
                summary.properties_failed = summary.properties_failed + 1
                entry_failures = entry_failures + 1
            end
        end

        if entry_changes > 0 then
            obj_mod.call_method_if_valid(light, "MarkRenderStateDirty")
        end

        entry.last_applied = {}
        entry.baseline = copy_snapshot(entry.original_snapshot)

        if entry_failures > 0 then
            summary.failed = summary.failed + 1
            if type(detail_logger) == "function" then
                detail_logger(string.format("partial restore failures=%d", entry_failures), entry.key)
            end
        else
            summary.restored = summary.restored + 1
            if type(detail_logger) == "function" then
                detail_logger("restored", entry.key)
            end
        end

        ::continue::
    end

    return summary
end

function M.prune_spotlight_cache(state)
    for key, entry in pairs(state.light_entries) do
        if entry.seen_cycle ~= state.apply_cycle and (not obj_mod.is_valid_object(entry.obj)) then
            state.light_entries[key] = nil
        end
    end

    local count = 0
    for _ in pairs(state.light_entries) do
        count = count + 1
    end
    state.stats.lights_cached = count
end

function M.is_tuning_effective(config)
    if config.spotlight_tune_enabled ~= true then
        return false
    end

    if config.spotlight_tune_mode == "absolute" then
        for _, key in pairs(FIELD_TO_ABSOLUTE) do
            local value = config[key]
            if type(value) == "number" and value >= 0 then
                return true
            end
        end
        return false
    end

    for _, key in pairs(FIELD_TO_MULTIPLIER) do
        local value = config[key]
        if type(value) == "number" and math.abs(value - 1.0) > EPSILON then
            return true
        end
    end

    return false
end

return M
