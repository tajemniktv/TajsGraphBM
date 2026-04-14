local log_mod = require("rt_log")
local obj_mod = require("rt_object")
local stats_mod = require("rt_stats")

local M = {
    __tajsgraph_module = "rt_render"
}

local log = log_mod.log
local safe_call = log_mod.safe_call

local function add_unique_target(targets, seen, obj)
    if not obj_mod.is_valid_object(obj) then
        return
    end

    local key = obj_mod.object_key(obj)
    if seen[key] then
        return
    end
    seen[key] = true
    table.insert(targets, obj)
end

local function collect_renderer_targets()
    local targets = {}
    local seen = {}
    local candidates = {
        "/Script/Engine.Default__RendererSettings",
        "/Script/Engine.RendererSettings",
    }

    for _, path in ipairs(candidates) do
        local ok_find, obj = safe_call(function()
            if type(StaticFindObject) == "function" then
                return StaticFindObject(path)
            end
            return nil
        end)
        if ok_find then
            add_unique_target(targets, seen, obj)
        end
    end

    local ok_first, first = safe_call(function()
        if type(FindFirstOf) == "function" then
            return FindFirstOf("RendererSettings")
        end
        return nil
    end)
    if ok_first then
        add_unique_target(targets, seen, first)
    end

    return targets
end

local function collect_postprocess_volumes()
    local ok_find, result = safe_call(function()
        if type(FindAllOf) == "function" then
            return FindAllOf("PostProcessVolume")
        end
        return nil
    end)

    if ok_find and type(result) == "table" then
        return result
    end
    return {}
end

local function collect_world_settings()
    local worlds = {}
    local seen = {}

    local ok_find_all, result = safe_call(function()
        if type(FindAllOf) == "function" then
            return FindAllOf("WorldSettings")
        end
        return nil
    end)

    if ok_find_all and type(result) == "table" then
        for _, ws in ipairs(result) do
            add_unique_target(worlds, seen, ws)
        end
    end

    local ok_first, first = safe_call(function()
        if type(FindFirstOf) == "function" then
            return FindFirstOf("WorldSettings")
        end
        return nil
    end)

    if ok_first then
        add_unique_target(worlds, seen, first)
    end

    -- Fallback: pull WorldSettings from active UWorld instances.
    local ok_worlds, world_list = safe_call(function()
        if type(FindAllOf) == "function" then
            return FindAllOf("World")
        end
        return nil
    end)
    if ok_worlds and type(world_list) == "table" then
        for _, world in ipairs(world_list) do
            if obj_mod.is_valid_object(world) then
                local ok_level, level = obj_mod.safe_get(world, "PersistentLevel")
                if ok_level and obj_mod.is_valid_object(level) then
                    local ok_ws, ws = obj_mod.safe_get(level, "WorldSettings")
                    if ok_ws then
                        add_unique_target(worlds, seen, ws)
                    end
                end
            end
        end
    end

    return worlds
end

function M.apply_render_compat(state, config)
    local function on_operation(bucket, success)
        stats_mod.count_operation(state, bucket, success)
    end

    local renderer_targets = collect_renderer_targets()
    local ppv_targets = collect_postprocess_volumes()
    local world_targets = collect_world_settings()

    if #renderer_targets == 0 and #ppv_targets == 0 and #world_targets == 0 then
        if not state.warned_no_render_targets then
            state.warned_no_render_targets = true
            if config.diagnostic_logging then
                log("diag render compat found no renderer/postprocess/world targets; skipping render writes")
            end
        end
        return
    end

    if config.diagnostic_logging then
        log(string.format(
            "diag render targets renderer=%d ppv=%d world=%d",
            #renderer_targets, #ppv_targets, #world_targets
        ))
    end

    for _, renderer in ipairs(renderer_targets) do
        if config.enable_megalights then
            obj_mod.guarded_write(renderer, "bEnableMegaLights", true, on_operation, "megalights")
            obj_mod.guarded_write(renderer, "bUseMegaLights", true, on_operation, "megalights")
            obj_mod.guarded_write(renderer, "bMegaLights", true, on_operation, "megalights")
            obj_mod.guarded_write(renderer, "MegaLightsShadowMethod", config.megalights_shadow_method, on_operation, "megalights")
            obj_mod.guarded_write(renderer, "ShadowMapMethod", config.megalights_shadow_method, on_operation, "megalights")
        end

        if config.force_lumen_methods then
            obj_mod.guarded_write(renderer, "DynamicGlobalIlluminationMethod", config.lumen_gi_method_value, on_operation, "lumen")
            obj_mod.guarded_write(renderer, "ReflectionMethod", config.lumen_reflection_method_value, on_operation, "lumen")
        end

        if config.force_lumen_compatibility then
            if config.lumen_disable_static_lighting then
                obj_mod.guarded_write(renderer, "bAllowStaticLighting", false, on_operation, "lumen")
            end
            if config.lumen_enable_mesh_distance_fields then
                obj_mod.guarded_write(renderer, "bGenerateMeshDistanceFields", true, on_operation, "lumen")
            end
            if config.lumen_disable_forward_shading then
                obj_mod.guarded_write(renderer, "bForwardShading", false, on_operation, "lumen")
            end
        end
    end

    for _, ppv in ipairs(ppv_targets) do
        if obj_mod.is_valid_object(ppv) then
            if config.enable_megalights then
                obj_mod.guarded_write(ppv, "bEnabled", true, on_operation, "megalights")
            end

            local ok_settings, settings = obj_mod.safe_get(ppv, "Settings")
            if ok_settings and settings ~= nil then
                if config.enable_megalights then
                    obj_mod.guarded_write(settings, "bOverride_ShadowMapMethod", true, on_operation, "megalights")
                    obj_mod.guarded_write(settings, "ShadowMapMethod", config.megalights_shadow_method, on_operation, "megalights")
                end

                if config.force_lumen_methods then
                    obj_mod.guarded_write(settings, "bOverride_DynamicGlobalIlluminationMethod", true, on_operation, "lumen")
                    obj_mod.guarded_write(settings, "DynamicGlobalIlluminationMethod", config.lumen_gi_method_value, on_operation, "lumen")
                    obj_mod.guarded_write(settings, "bOverride_ReflectionMethod", true, on_operation, "lumen")
                    obj_mod.guarded_write(settings, "ReflectionMethod", config.lumen_reflection_method_value, on_operation, "lumen")
                end

                if config.force_lumen_compatibility then
                    obj_mod.guarded_write(settings, "bOverride_LumenSceneDetail", true, on_operation, "lumen")
                    obj_mod.guarded_write(settings, "LumenSceneDetail", config.lumen_scene_detail, on_operation, "lumen")
                    obj_mod.guarded_write(settings, "bOverride_LumenDiffuseColorBoost", true, on_operation, "lumen")
                    obj_mod.guarded_write(settings, "LumenDiffuseColorBoost", config.lumen_diffuse_color_boost, on_operation, "lumen")
                    obj_mod.guarded_write(settings, "bOverride_LumenSkylightLeaking", true, on_operation, "lumen")
                    obj_mod.guarded_write(settings, "LumenSkylightLeaking", config.lumen_skylight_leaking, on_operation, "lumen")
                    obj_mod.guarded_write(settings, "bOverride_LumenMaxTraceDistance", true, on_operation, "lumen")
                    obj_mod.guarded_write(settings, "LumenMaxTraceDistance", config.lumen_max_trace_distance, on_operation, "lumen")
                end
            end
        end
    end

    for _, world_settings in ipairs(world_targets) do
        if obj_mod.is_valid_object(world_settings) then
            if config.force_lumen_methods then
                obj_mod.guarded_write(world_settings, "DynamicGlobalIlluminationMethod", config.lumen_gi_method_value, on_operation, "lumen")
                obj_mod.guarded_write(world_settings, "ReflectionMethod", config.lumen_reflection_method_value, on_operation, "lumen")
            end

            if config.force_lumen_compatibility and config.lumen_force_no_precomputed_lighting then
                obj_mod.guarded_write(world_settings, "bForceNoPrecomputedLighting", true, on_operation, "lumen")
            end
        end
    end
end

return M
