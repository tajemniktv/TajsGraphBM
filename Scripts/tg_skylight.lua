local M = {}

local ok_utils, utils = pcall(require, "tg_utils")
local ok_state, s = pcall(require, "tg_state")
local ok_cfg, c = pcall(require, "tg_config")

local STATE = (ok_state and type(s) == "table") and s.STATE or error("tg_skylight: missing tg_state")
local CONFIG = (ok_cfg and type(c) == "table") and c.CONFIG or error("tg_skylight: missing tg_config")
local is_valid = (ok_utils and utils and utils.is_valid) or function() return false end
local get_field = (ok_utils and utils and utils.get_field) or function() return false end
local set_field = (ok_utils and utils and utils.set_field) or function() return false end
local call_method_if_valid = (ok_utils and utils and utils.call_method_if_valid) or function() return false end
local set_number_property_confirmed = (ok_utils and utils and utils.set_number_property_confirmed) or
function() return false end
local set_bool_property_confirmed = (ok_utils and utils and utils.set_bool_property_confirmed) or
function() return false end
local safe_inc_reason = (ok_utils and utils and utils.safe_inc_reason) or function() end
local get_time_ms = (ok_utils and utils and utils.get_time_ms) or function() return 0 end
local get_objects_of_class = (ok_utils and utils and utils.get_objects_of_class) or function() return {} end
local log = (ok_utils and utils and utils.log) or function(msg) print(tostring(msg)) end
local get_light_key = function(obj)
	local ok, name = pcall(function() return obj:GetFullName() end)
	if ok and type(name) == "string" and name ~= "" then return name end
	return tostring(obj)
end

local function collect_skylight_components()
	local components = {}
	local seen = {}

	local function add_component(comp)
		if not is_valid(comp) then
			return
		end
		local key = get_light_key(comp)
		if seen[key] then
			return
		end
		seen[key] = true
		components[#components + 1] = comp
	end

	for _, actor in ipairs(get_objects_of_class("SkyLight")) do
		STATE.skylight_found = STATE.skylight_found + 1
		if is_valid(actor) then
			local ok_comp, comp = get_field(actor, "LightComponent")
			if ok_comp and comp ~= nil then
				add_component(comp)
			else
				safe_inc_reason(STATE.skylight_fail_reasons, "actor_missing_component")
			end
		else
			safe_inc_reason(STATE.skylight_fail_reasons, "invalid_skylight_actor")
		end
	end

	for _, comp in ipairs(get_objects_of_class("SkyLightComponent")) do
		STATE.skylight_found = STATE.skylight_found + 1
		add_component(comp)
	end

	return components
end

local function maybe_patch_skylights(on_patch)
	if not CONFIG.skylight_runtime_pass then
		return
	end

	local now_ms = get_time_ms()
	for _, comp in ipairs(collect_skylight_components()) do
		if not is_valid(comp) then
			safe_inc_reason(STATE.skylight_fail_reasons, "invalid_skylight_component")
		else
			STATE.skylight_valid = STATE.skylight_valid + 1

			local key = get_light_key(comp)
			local patched_any = false

			if CONFIG.skylight_force_movable then
				local mobility_ok = call_method_if_valid(comp, "SetMobility", CONFIG.force_light_movable_value)
				if not mobility_ok then
					mobility_ok = set_field(comp, "Mobility", CONFIG.force_light_movable_value)
				end
				local ok_mobility, mobility = get_field(comp, "Mobility")
				if mobility_ok and ok_mobility and tonumber(mobility) == CONFIG.force_light_movable_value then
					STATE.skylight_movable_forced = STATE.skylight_movable_forced + 1
					patched_any = true
				elseif not mobility_ok then
					STATE.skylight_write_fail = STATE.skylight_write_fail + 1
					safe_inc_reason(STATE.skylight_fail_reasons, "mobility_write_failed")
				end
			end

			local realtime_ok = false
			if CONFIG.skylight_enable_realtime_capture then
				realtime_ok = call_method_if_valid(comp, "SetRealTimeCapture", true)
				if not realtime_ok then
					realtime_ok = set_bool_property_confirmed(comp, "bRealTimeCapture", true)
				else
					local ok_rt, current_rt = get_field(comp, "bRealTimeCapture")
					realtime_ok = ok_rt and current_rt == true
				end

				if realtime_ok then
					STATE.skylight_realtime_enabled = STATE.skylight_realtime_enabled + 1
					patched_any = true
				else
					STATE.skylight_write_fail = STATE.skylight_write_fail + 1
					safe_inc_reason(STATE.skylight_fail_reasons, "realtime_capture_unavailable")
				end
			end

			local baseline = STATE.skylight_scale_baseline[key]
			if baseline == nil then
				baseline = {}
				local ok_intensity, base_intensity = get_field(comp, "Intensity")
				if ok_intensity and type(base_intensity) == "number" then
					baseline.intensity = base_intensity
				end
				local ok_indirect, base_indirect = get_field(comp, "IndirectLightingIntensity")
				if ok_indirect and type(base_indirect) == "number" then
					baseline.indirect = base_indirect
				end
				STATE.skylight_scale_baseline[key] = baseline
			end

			if type(baseline.intensity) == "number" and CONFIG.skylight_intensity_multiplier ~= 1.0 then
				local target_intensity = baseline.intensity * CONFIG.skylight_intensity_multiplier
				if set_number_property_confirmed(comp, "Intensity", target_intensity, "SetIntensity") then
					STATE.skylight_intensity_scaled = STATE.skylight_intensity_scaled + 1
					patched_any = true
				else
					STATE.skylight_write_fail = STATE.skylight_write_fail + 1
					safe_inc_reason(STATE.skylight_fail_reasons, "intensity_scale_failed")
				end
			end

			if type(baseline.indirect) == "number" and CONFIG.skylight_indirect_multiplier ~= 1.0 then
				local target_indirect = baseline.indirect * CONFIG.skylight_indirect_multiplier
				if set_number_property_confirmed(comp, "IndirectLightingIntensity", target_indirect, "SetIndirectLightingIntensity") then
					STATE.skylight_indirect_scaled = STATE.skylight_indirect_scaled + 1
					patched_any = true
				else
					STATE.skylight_write_fail = STATE.skylight_write_fail + 1
					safe_inc_reason(STATE.skylight_fail_reasons, "indirect_scale_failed")
				end
			end

			if CONFIG.skylight_lower_specular_if_needed then
				local ok_contrast, contrast = get_field(comp, "Contrast")
				if ok_contrast and type(contrast) == "number" and contrast > 0.8 then
					if set_number_property_confirmed(comp, "Contrast", 0.8, "SetOcclusionContrast") then
						patched_any = true
					else
						STATE.skylight_write_fail = STATE.skylight_write_fail + 1
						safe_inc_reason(STATE.skylight_fail_reasons, "specular_lower_failed")
					end
				end
			end

			local should_recapture = false
			if on_patch and CONFIG.skylight_recapture_on_patch then
				should_recapture = true
			end
			if CONFIG.skylight_recapture_interval_ms > 0 then
				local last_ms = STATE.skylight_last_recapture_ms[key] or 0
				if now_ms - last_ms >= CONFIG.skylight_recapture_interval_ms then
					should_recapture = true
				end
			end

			if should_recapture and (not realtime_ok or CONFIG.skylight_recapture_on_patch or CONFIG.skylight_recapture_interval_ms > 0) then
				STATE.skylight_recapture_attempted = STATE.skylight_recapture_attempted + 1
				if call_method_if_valid(comp, "RecaptureSky") then
					STATE.skylight_recapture_ok = STATE.skylight_recapture_ok + 1
					STATE.skylight_last_recapture_ms[key] = now_ms
					patched_any = true
				else
					STATE.skylight_write_fail = STATE.skylight_write_fail + 1
					safe_inc_reason(STATE.skylight_fail_reasons, "recapture_failed")
				end
			end

			if patched_any then
				STATE.skylight_patched = STATE.skylight_patched + 1
			end
		end
	end
end

M.collect_skylight_components = collect_skylight_components
M.maybe_patch_skylights = maybe_patch_skylights

return M
