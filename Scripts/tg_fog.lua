local ok_utils, utils = pcall(require, "tg_utils")
local ok_state, s = pcall(require, "tg_state")
local ok_cfg, c = pcall(require, "tg_config")
local ok_lights, lights = pcall(require, "tg_lights")

local STATE = (ok_state and type(s) == "table") and s.STATE or nil
local CONFIG = (ok_cfg and type(c) == "table") and c.CONFIG or nil

local log = (ok_utils and utils and utils.log) or function(msg) print(msg) end
local is_valid = utils and utils.is_valid
local get_field = utils and utils.get_field
local get_objects_of_class = utils and utils.get_objects_of_class
local set_bool_property_confirmed = utils and utils.set_bool_property_confirmed
local safe_inc_reason = utils and utils.safe_inc_reason

local get_light_key = (ok_lights and lights and lights.get_light_key) or function(light_comp)
	local key_ok, key = pcall(function()
		return light_comp:GetFullName()
	end)

	if key_ok and type(key) == "string" and key ~= "" then
		return key
	end

	return tostring(light_comp)
end

local M = {}

local function collect_fog_targets()
	local targets = {}
	local seen = {}

	local function add_target(obj)
		if not is_valid(obj) then
			return
		end
		local key = get_light_key(obj)
		if seen[key] then
			return
		end
		seen[key] = true
		targets[#targets + 1] = obj
	end

	for _, fog in ipairs(get_objects_of_class("ExponentialHeightFog")) do
		if STATE then STATE.fog_actors_found = (STATE.fog_actors_found or 0) + 1 end
		add_target(fog)
		local field_names = { "Component", "ExponentialHeightFogComponent", "FogComponent" }
		for _, field_name in ipairs(field_names) do
			local ok_comp, comp = get_field(fog, field_name)
			if ok_comp and comp ~= nil then
				add_target(comp)
			end
		end
	end

	for _, comp in ipairs(get_objects_of_class("ExponentialHeightFogComponent")) do
		if STATE then STATE.fog_actors_found = (STATE.fog_actors_found or 0) + 1 end
		add_target(comp)
	end

	return targets
end

local function maybe_patch_fog(_on_patch)
	if not CONFIG or not CONFIG.fog_runtime_pass then
		return
	end

	for _, fog_obj in ipairs(collect_fog_targets()) do
		if not is_valid(fog_obj) then
			if STATE then safe_inc_reason(STATE.fog_fail_reasons, "invalid_fog_object") end
		else
			if STATE then STATE.fog_valid = (STATE.fog_valid or 0) + 1 end

			if CONFIG.fog_enable_exponential_height_fog then
				local enabled = false
				if set_bool_property_confirmed(fog_obj, "bEnabled", true) then
					enabled = true
				elseif set_bool_property_confirmed(fog_obj, "bVisible", true) then
					enabled = true
				end
				if enabled then
					if STATE then STATE.fog_enabled = (STATE.fog_enabled or 0) + 1 end
				else
					if STATE then STATE.fog_write_fail = (STATE.fog_write_fail or 0) + 1 end
					if STATE then safe_inc_reason(STATE.fog_fail_reasons, "fog_enable_failed") end
				end
			end

			if CONFIG.fog_enable_volumetric_fog then
				if set_bool_property_confirmed(fog_obj, "bEnableVolumetricFog", true) then
					if STATE then STATE.fog_volumetric_enabled = (STATE.fog_volumetric_enabled or 0) + 1 end
				else
					if STATE then safe_inc_reason(STATE.fog_fail_reasons, "volumetric_flag_unavailable") end
				end
			end

			if CONFIG.fog_try_lumen_fog_helpers then
				local probe_fields = {
					"VolumetricFogScatteringDistribution",
					"VolumetricFogExtinctionScale",
					"FogDensity",
					"FogMaxOpacity",
				}
				for _, field_name in ipairs(probe_fields) do
					local ok_probe, _ = get_field(fog_obj, field_name)
					if ok_probe and STATE then
						STATE.fog_lumen_fields_seen = (STATE.fog_lumen_fields_seen or 0) + 1
					end
				end
			end
		end
	end
end

M.collect_fog_targets = collect_fog_targets
M.maybe_patch_fog = maybe_patch_fog

return M
