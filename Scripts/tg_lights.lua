local ok_utils, utils = pcall(require, "tg_utils")
local ok_state, s = pcall(require, "tg_state")
local ok_cfg, c = pcall(require, "tg_config")

local STATE = (ok_state and type(s) == "table") and s.STATE or nil
local CONFIG = (ok_cfg and type(c) == "table") and c.CONFIG or nil

local log = (ok_utils and utils and utils.log) or function(msg) print(msg) end
local is_valid = utils and utils.is_valid
local get_field = utils and utils.get_field
local set_field = utils and utils.set_field
local call_method_if_valid = utils and utils.call_method_if_valid
local set_numeric_property = utils and utils.set_numeric_property
local set_bool_property_confirmed = utils and utils.set_bool_property_confirmed
local set_number_property_confirmed = utils and utils.set_number_property_confirmed
local set_bool_property_multi = utils and utils.set_bool_property_multi
local safe_inc_reason = utils and utils.safe_inc_reason
local get_time_ms = utils and utils.get_time_ms
local get_objects_of_class = utils and utils.get_objects_of_class

local M = {}

local function get_light_key(light_comp)
	local key_ok, key = pcall(function()
		return light_comp:GetFullName()
	end)

	if key_ok and type(key) == "string" and key ~= "" then
		return key
	end

	return tostring(light_comp)
end

local function get_target_light_classes()
	local classes = {
		"PointLightComponent",
		"SpotLightComponent",
	}

	if CONFIG and CONFIG.include_rect_light_component then
		classes[#classes + 1] = "RectLightComponent"
	end

	if CONFIG and CONFIG.include_generic_light_component then
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
	if is_valid and is_valid(comp) then
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
	if not is_valid or not is_valid(light_comp) then
		return false
	end

	set_field(light_comp, "bAffectsWorld", true)
	set_field(light_comp, "bVisible", true)
	set_field(light_comp, "bEnabled", true)

	return is_valid(light_comp)
end

local function should_entry_cast_shadows(entry)
	if not CONFIG then return false end
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
	if not is_valid or not is_valid(light_comp) then
		return false
	end

	if not CONFIG then return false end
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
	if record_stats and STATE then
		STATE.tune_attempted_last = STATE.tune_attempted_last + 1
	end
	local changed_any = false

	local function apply_tuned_value(field_name, value, setter_name)
		local ok = set_numeric_property(light_comp, field_name, value, setter_name)
		if ok then
			changed_any = true
			return true
		end

		if record_stats and STATE then
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

	if changed_any and record_stats and STATE then
		STATE.tune_changed_last = STATE.tune_changed_last + 1
	end

	return changed_any
end

local function enforce_light_megalights(light_comp, entry, record_stats)
	local track = record_stats ~= false
	if track and STATE then
		STATE.megalights_attempted_last = STATE.megalights_attempted_last + 1
	end

	local target_method = (CONFIG and CONFIG.megalights_shadow_method) or 0
	local wrote_enabled = set_field(light_comp, "bAllowMegaLights", true)
	local wrote_method = set_field(light_comp, "MegaLightsShadowMethod", target_method)

	local has_enabled, current_enabled = get_field(light_comp, "bAllowMegaLights")
	local has_method, current_method = get_field(light_comp, "MegaLightsShadowMethod")
	local enabled_ok = wrote_enabled or (has_enabled and current_enabled == true)
	local method_ok = wrote_method or (has_method and tonumber(current_method) == target_method)
	local ok = enabled_ok and method_ok

	if track and STATE then
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
	if STATE then STATE.prepatch_captured_last = STATE.prepatch_captured_last + 1 end
end

local function reset_spotlight_baselines()
	local reset_count = 0
	if not STATE then return end
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
	if not is_valid or not is_valid(light_comp) then
		if STATE then STATE.skipped_invalid = STATE.skipped_invalid + 1 end
		return false
	end

	capture_spotlight_prepatch(entry, light_comp)

	if not enable_light_component(light_comp) then
		if STATE then STATE.skipped_invalid = STATE.skipped_invalid + 1 end
		entry.patched = false
		return false
	end
	if STATE then STATE.enable_ops_last = STATE.enable_ops_last + 1 end
	entry.enabled_state = true

	enforce_light_megalights(light_comp, entry, true)

	if CONFIG and CONFIG.force_light_movable then
		local mobility_applied = call_method_if_valid(light_comp, "SetMobility", CONFIG.force_light_movable_value)
		if not mobility_applied then
			mobility_applied = set_field(light_comp, "Mobility", CONFIG.force_light_movable_value)
		end
	end

	if get_entry_light_kind(entry) == "SpotLightComponent" then
		if tune_spotlight(light_comp, entry) and not entry.spot_tuned then
			entry.spot_tuned = true
			if STATE then STATE.spot_tuned_last = STATE.spot_tuned_last + 1 end
		end
	end

	entry.patched = true
	local cast_shadows = should_entry_cast_shadows(entry)
	if set_light_shadow(light_comp, cast_shadows) then
		if STATE then STATE.shadow_ops_last = STATE.shadow_ops_last + 1 end
		entry.shadow_forced = cast_shadows
	else
		entry.shadow_forced = nil
	end
	return true
end

local function count_patched_total()
	local n = 0
	if not STATE then return 0 end
	for _, entry in pairs(STATE.light_entries) do
		if entry.patched then
			n = n + 1
		end
	end
	return n
end

local function refresh_light_cache()
	if not STATE then return end
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
	if STATE then
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
	end

	if force_reapply and STATE then
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
			if STATE then STATE.patched_runtime_last = STATE.patched_runtime_last + 1 end
		end
	end

	if STATE then
		STATE.lights_patched_last = patched_now
		STATE.lights_patched_total = count_patched_total()
	end
end

local function refresh_shadow_slots()
	if not STATE then return end
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
	if not STATE or not CONFIG then return end
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
	if not STATE or not CONFIG then return end
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
	if CONFIG and CONFIG.force_lumen_methods then
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
	if not CONFIG or not CONFIG.touch_postprocess_volume then
		if STATE then
			STATE.ppv_scanned = 0
			STATE.ppv_enabled = 0
		end
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

	if STATE then
		STATE.ppv_scanned = scanned
		STATE.ppv_enabled = enabled_count
	end
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

M.get_light_key = get_light_key
M.get_target_light_classes = get_target_light_classes
M.set_light_shadow = set_light_shadow
M.get_entry_light_kind = get_entry_light_kind
M.enable_light_component = enable_light_component
M.should_entry_cast_shadows = should_entry_cast_shadows
M.tune_spotlight = tune_spotlight
M.enforce_light_megalights = enforce_light_megalights
M.capture_spotlight_prepatch = capture_spotlight_prepatch
M.reset_spotlight_baselines = reset_spotlight_baselines
M.patch_light_entry = patch_light_entry
M.count_patched_total = count_patched_total
M.refresh_light_cache = refresh_light_cache
M.patch_cached_lights = patch_cached_lights
M.refresh_shadow_slots = refresh_shadow_slots
M.set_renderer_megalights = set_renderer_megalights
M.apply_world_lumen_compatibility = apply_world_lumen_compatibility
M.apply_ppv_settings = apply_ppv_settings
M.set_postprocess_megalights = set_postprocess_megalights
M.run_console_command = run_console_command

return M
