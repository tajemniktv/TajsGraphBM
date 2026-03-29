local M = {}

local tg_utils = nil
if type(require) == "function" then
	local ok, u = pcall(require, "tg_utils")
	if ok and type(u) == "table" then
		tg_utils = u
	end
end
if not tg_utils then
	error("failed to load module 'tg_utils'")
end

local tg_config = nil
if type(require) == "function" then
	local ok, c = pcall(require, "tg_config")
	if ok and type(c) == "table" and type(c.CONFIG) == "table" then
		tg_config = c
	end
end
if not tg_config then
	error("failed to load module 'tg_config'")
end

local tg_state = nil
if type(require) == "function" then
	local ok, s = pcall(require, "tg_state")
	if ok and type(s) == "table" and type(s.STATE) == "table" then
		tg_state = s
	end
end
if not tg_state then
	error("failed to load module 'tg_state'")
end

local tg_autocomplete = nil
if type(require) == "function" then
	local ok_ac, ac = pcall(require, "tg_autocomplete")
	if ok_ac and type(ac) == "table" then
		tg_autocomplete = ac
	end
end

local CONFIG = tg_config.CONFIG
local STATE = tg_state.STATE
local utils = tg_utils

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
local get_objects_of_class = utils.get_objects_of_class

local trim = function(s) return string.match(s, "^%s*(.-)%s*$") end
if tg_autocomplete and type(tg_autocomplete.trim) == "function" then
	trim = tg_autocomplete.trim
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

local function get_target_mesh_component_classes()
	local classes = {
		"StaticMeshComponent",
		"InstancedStaticMeshComponent",
		"HierarchicalInstancedStaticMeshComponent",
		"FoliageInstancedStaticMeshComponent",
	}

	if CONFIG.mesh_include_skeletal_components then
		classes[#classes + 1] = "SkeletalMeshComponent"
	end

	return classes
end

local function normalize_axis_name(axis)
	if type(axis) ~= "string" then
		return "x"
	end

	local value = string.lower(axis)
	if value ~= "x" and value ~= "y" and value ~= "z" then
		return "x"
	end

	return value
end

local function try_apply_pseudo_thickness(comp)
	if not CONFIG.mesh_pseudo_thickness_enabled then
		return true
	end

	local axis = normalize_axis_name(CONFIG.mesh_pseudo_thickness_axis)
	local multiplier = CONFIG.mesh_pseudo_thickness_multiplier
	if type(multiplier) ~= "number" or multiplier <= 0.0 then
		return false
	end

	local ok_scale, scale = get_field(comp, "RelativeScale3D")
	if not ok_scale or scale == nil then
		ok_scale, scale = get_field(comp, "Scale3D")
	end
	if not ok_scale or scale == nil then
		return false
	end

	local write_ok = pcall(function()
		if axis == "x" then
			scale.X = tonumber(scale.X) * multiplier
		elseif axis == "y" then
			scale.Y = tonumber(scale.Y) * multiplier
		else
			scale.Z = tonumber(scale.Z) * multiplier
		end
	end)
	if not write_ok then
		return false
	end

	if call_method_if_valid(comp, "SetRelativeScale3D", scale) then
		return true
	end
	if call_method_if_valid(comp, "SetWorldScale3D", scale) then
		return true
	end
	if set_field(comp, "RelativeScale3D", scale) then
		return true
	end
	if set_field(comp, "Scale3D", scale) then
		return true
	end

	return false
end

local function contains_any_name_filter(key_lower)
	local filters = CONFIG.mesh_name_filters
	if type(filters) ~= "table" or #filters == 0 then
		return true
	end

	for _, raw_filter in ipairs(filters) do
		if type(raw_filter) == "string" and raw_filter ~= "" then
			local filter = string.lower(raw_filter)
			if string.find(key_lower, filter, 1, true) ~= nil then
				return true
			end
		end
	end

	return false
end

local function matches_filter_with_basename(key_lower, raw_filter)
	if type(raw_filter) ~= "string" or raw_filter == "" then
		return false
	end

	local filter = string.lower(raw_filter)
	if string.find(key_lower, filter, 1, true) ~= nil then
		return true
	end

	local basename = string.match(filter, "([^/]+)$")
	if basename ~= nil and basename ~= "" and basename ~= filter then
		if string.find(key_lower, basename, 1, true) ~= nil then
			return true
		end
	end

	return false
end

local function contains_any_scope_include(key_lower)
	local filters = CONFIG.mesh_scope_include_filters
	if type(filters) ~= "table" or #filters == 0 then
		return true
	end

	for _, raw_filter in ipairs(filters) do
		if matches_filter_with_basename(key_lower, raw_filter) then
			return true
		end
	end

	return false
end

local function matches_any_scope_exclude(key_lower)
	local filters = CONFIG.mesh_scope_exclude_filters
	if type(filters) ~= "table" or #filters == 0 then
		return false
	end

	for _, raw_filter in ipairs(filters) do
		if matches_filter_with_basename(key_lower, raw_filter) then
			return true
		end
	end

	return false
end

local function get_mesh_candidate_rejection_reason(entry)
	if entry == nil or not is_valid(entry.comp) then
		return "invalid"
	end

	local key_lower = string.lower(tostring(entry.key or ""))
	if not contains_any_scope_include(key_lower) then
		return "scope_include"
	end

	if matches_any_scope_exclude(key_lower) then
		return "scope_exclude"
	end

	if not contains_any_name_filter(key_lower) then
		return "name_filter"
	end

	if CONFIG.mesh_skip_movable then
		local ok_mobility, mobility = get_field(entry.comp, "Mobility")
		if ok_mobility and tonumber(mobility) == 2 then
			return "movable"
		end
	end

	return nil
end

local function is_mesh_component_candidate(entry)
	return get_mesh_candidate_rejection_reason(entry) == nil
end

local function refresh_mesh_cache()
	STATE.mesh_refresh_seq = STATE.mesh_refresh_seq + 1

	local found = 0
	local foliage_found = 0
	local skeletal_found = 0
	local ism_found = 0
	local hism_found = 0
	local seen = {}
	for _, class_name in ipairs(get_target_mesh_component_classes()) do
		for _, comp in ipairs(get_objects_of_class(class_name)) do
			if is_valid(comp) then
				local key = get_light_key(comp)
				if not seen[key] then
					seen[key] = true
					found = found + 1

					local detected_class_name = get_component_class_name(comp, class_name)
					local class_lower = string.lower(tostring(detected_class_name or ""))
					if string.find(class_lower, "foliage", 1, true) ~= nil then
						foliage_found = foliage_found + 1
					end
					if string.find(class_lower, "skeletal", 1, true) ~= nil then
						skeletal_found = skeletal_found + 1
					end
					if string.find(class_lower, "hierarchicalinstancedstaticmeshcomponent", 1, true) ~= nil then
						hism_found = hism_found + 1
					end
					if string.find(class_lower, "instancedstaticmeshcomponent", 1, true) ~= nil and string.find(class_lower, "hierarchical", 1, true) == nil then
						ism_found = ism_found + 1
					end

					local entry = STATE.mesh_entries[key]
					if entry == nil then
						STATE.mesh_entries[key] = {
							key = key,
							comp = comp,
							class_name = detected_class_name,
							patched = false,
							last_seen = STATE.mesh_refresh_seq,
						}
					else
						entry.comp = comp
						entry.class_name = detected_class_name
						entry.last_seen = STATE.mesh_refresh_seq
					end
				end
			end
		end
	end

	for key, entry in pairs(STATE.mesh_entries) do
		if entry.last_seen ~= STATE.mesh_refresh_seq or not is_valid(entry.comp) then
			STATE.mesh_entries[key] = nil
		end
	end

	local candidates = 0
	local foliage_candidates = 0
	local skeletal_candidates = 0
	local ism_candidates = 0
	local hism_candidates = 0
	for _, entry in pairs(STATE.mesh_entries) do
		if is_mesh_component_candidate(entry) then
			candidates = candidates + 1
			local class_lower = string.lower(tostring(entry.class_name or ""))
			if string.find(class_lower, "foliage", 1, true) ~= nil then
				foliage_candidates = foliage_candidates + 1
			end
			if string.find(class_lower, "skeletal", 1, true) ~= nil then
				skeletal_candidates = skeletal_candidates + 1
			end
			if string.find(class_lower, "hierarchicalinstancedstaticmeshcomponent", 1, true) ~= nil then
				hism_candidates = hism_candidates + 1
			end
			if string.find(class_lower, "instancedstaticmeshcomponent", 1, true) ~= nil and string.find(class_lower, "hierarchical", 1, true) == nil then
				ism_candidates = ism_candidates + 1
			end
		end
	end

	STATE.mesh_components_found = found
	STATE.mesh_components_candidates = candidates
	STATE.mesh_foliage_components_found = foliage_found
	STATE.mesh_foliage_components_candidates = foliage_candidates
	STATE.mesh_skeletal_components_found = skeletal_found
	STATE.mesh_skeletal_components_candidates = skeletal_candidates
	STATE.mesh_ism_components_found = ism_found
	STATE.mesh_ism_components_candidates = ism_candidates
	STATE.mesh_hism_components_found = hism_found
	STATE.mesh_hism_components_candidates = hism_candidates
end

local function count_mesh_patched_total()
	local n = 0
	for _, entry in pairs(STATE.mesh_entries) do
		if entry.patched then
			n = n + 1
		end
	end

	return n
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

local function patch_mesh_entry(entry)
	if entry == nil or not is_valid(entry.comp) then
		return false
	end

	local rejection_reason = get_mesh_candidate_rejection_reason(entry)
	if rejection_reason ~= nil then
		entry.patched = false
		entry.last_skip_reason = rejection_reason
		if rejection_reason == "scope_include" or rejection_reason == "scope_exclude" then
			STATE.mesh_scope_skipped_last = STATE.mesh_scope_skipped_last + 1
		elseif rejection_reason ~= "invalid" then
			STATE.mesh_filter_skipped_last = STATE.mesh_filter_skipped_last + 1
		end
		return false
	end

	entry.last_skip_reason = nil

	local comp = entry.comp
	local changed_any = false

	if CONFIG.mesh_force_generate_mesh_distance_field then
		local static_mesh = get_object_property(comp, "StaticMesh")
		if is_valid(static_mesh) then
			set_bool_property_confirmed(static_mesh, "bGenerateMeshDistanceField", true, nil)
		end
	end

	local function apply_bool(field_names, enabled, setter_name)
		if enabled ~= true then
			return true
		end

		local ok = set_bool_property_multi(comp, field_names, true, setter_name)
		if ok then
			changed_any = true
			STATE.mesh_force_apply_ops_last = STATE.mesh_force_apply_ops_last + 1
			return true
		end

		STATE.mesh_write_fail_last = STATE.mesh_write_fail_last + 1
		return false
	end

	apply_bool({ "CastShadow", "bCastShadow" }, CONFIG.mesh_force_cast_shadow, "SetCastShadow")
	apply_bool({ "bCastDynamicShadow" }, CONFIG.mesh_force_dynamic_shadow, nil)
	apply_bool({ "bCastStaticShadow" }, CONFIG.mesh_force_static_shadow, nil)
	apply_bool({ "bCastShadowAsTwoSided" }, CONFIG.mesh_force_two_sided_shadow, nil)
	apply_bool({ "bAffectDynamicIndirectLighting" }, CONFIG.mesh_force_affect_dynamic_indirect_lighting,
		"SetAffectDynamicIndirectLighting")
	apply_bool({ "bAffectIndirectLightingWhileHidden" }, CONFIG.mesh_force_affect_indirect_lighting_while_hidden,
		"SetAffectIndirectLightingWhileHidden")
	apply_bool({ "bAffectDistanceFieldLighting" }, CONFIG.mesh_force_affect_distance_field_lighting,
		"SetAffectDistanceFieldLighting")
	apply_bool({ "bCastDistanceFieldIndirectShadow" }, CONFIG.mesh_force_distance_field_indirect_shadow, nil)
	apply_bool({ "bVisibleInRayTracing" }, CONFIG.mesh_force_visible_in_ray_tracing, "SetVisibleInRayTracing")
	apply_bool({ "bVisibleInReflectionCaptures" }, CONFIG.mesh_force_visible_in_reflection_captures, nil)
	apply_bool({ "bVisibleInRealTimeSkyCaptures" }, CONFIG.mesh_force_visible_in_realtime_sky_captures, nil)
	apply_bool({ "bVisible", "Visible" }, CONFIG.mesh_force_component_visible, "SetVisibility")
	apply_bool({ "bUseAsOccluder" }, CONFIG.mesh_force_use_as_occluder, nil)
	apply_bool({ "bRenderInMainPass" }, CONFIG.mesh_force_render_in_main_pass, nil)
	apply_bool({ "bRenderInDepthPass" }, CONFIG.mesh_force_render_in_depth_pass, nil)

	if CONFIG.mesh_force_bounds_scale then
		local bounds_ok = set_number_property_confirmed(comp, "BoundsScale", CONFIG.mesh_bounds_scale, "SetBoundsScale")
		if bounds_ok then
			changed_any = true
			STATE.mesh_bounds_scale_ops_last = STATE.mesh_bounds_scale_ops_last + 1
		else
			STATE.mesh_bounds_scale_fail_last = STATE.mesh_bounds_scale_fail_last + 1
		end
	end

	if CONFIG.mesh_force_never_distance_cull then
		local never_cull_ok = set_bool_property_confirmed(comp, "bNeverDistanceCull", true)
		if never_cull_ok then
			changed_any = true
			STATE.mesh_cull_distance_ops_last = STATE.mesh_cull_distance_ops_last + 1
		else
			STATE.mesh_cull_distance_fail_last = STATE.mesh_cull_distance_fail_last + 1
		end
	end

	if CONFIG.mesh_disable_cull_distance_volume then
		local cull_volume_ok = set_bool_property_confirmed(comp, "bAllowCullDistanceVolume", false)
		if cull_volume_ok then
			changed_any = true
			STATE.mesh_cull_distance_ops_last = STATE.mesh_cull_distance_ops_last + 1
		else
			STATE.mesh_cull_distance_fail_last = STATE.mesh_cull_distance_fail_last + 1
		end
	end

	if CONFIG.mesh_force_zero_max_draw_distance then
		local max_draw_ok = set_number_property_confirmed(comp, "LDMaxDrawDistance", 0.0, nil)
		if not max_draw_ok then
			max_draw_ok = set_number_property_confirmed(comp, "CachedMaxDrawDistance", 0.0, nil)
		end
		if not max_draw_ok then
			max_draw_ok = set_number_property_confirmed(comp, "MaxDrawDistance", 0.0, nil)
		end

		if max_draw_ok then
			changed_any = true
			STATE.mesh_cull_distance_ops_last = STATE.mesh_cull_distance_ops_last + 1
		else
			STATE.mesh_cull_distance_fail_last = STATE.mesh_cull_distance_fail_last + 1
		end
	end

	if CONFIG.mesh_force_zero_instance_cull_distances then
		local cull_ok = call_method_if_valid(comp, "SetCullDistances", 0, 0)
		if not cull_ok then
			local start_ok = set_number_property_confirmed(comp, "InstanceStartCullDistance", 0.0, nil)
			local end_ok = set_number_property_confirmed(comp, "InstanceEndCullDistance", 0.0, nil)
			cull_ok = start_ok or end_ok
		end

		if cull_ok then
			changed_any = true
			STATE.mesh_cull_distance_ops_last = STATE.mesh_cull_distance_ops_last + 1
		else
			STATE.mesh_cull_distance_fail_last = STATE.mesh_cull_distance_fail_last + 1
		end
	end

	if CONFIG.mesh_pseudo_thickness_enabled then
		if CONFIG.mesh_pseudo_thickness_require_name_filters and not contains_any_name_filter(string.lower(tostring(entry.key or ""))) then
			-- Skip pseudo thickness when no name filter matched to avoid unintended scaling
		else
			local thickness_ok = try_apply_pseudo_thickness(comp)
			if thickness_ok then
				changed_any = true
				STATE.mesh_pseudo_thickness_ops_last = STATE.mesh_pseudo_thickness_ops_last + 1
			else
				STATE.mesh_pseudo_thickness_fail_last = STATE.mesh_pseudo_thickness_fail_last + 1
			end
		end
	end

	if CONFIG.mesh_invalidate_lumen_surface_cache then
		local ok_lumen = call_method_if_valid(comp, "InvalidateLumenSurfaceCache")
		if ok_lumen then
			STATE.mesh_lumen_cache_invalidations_last = STATE.mesh_lumen_cache_invalidations_last + 1
		else
			STATE.mesh_lumen_cache_invalidation_fail_last = STATE.mesh_lumen_cache_invalidation_fail_last + 1
		end
	end

	if CONFIG.mesh_force_render_state_dirty then
		local ok_dirty = call_method_if_valid(comp, "MarkRenderStateDirty")
		if not ok_dirty then
			ok_dirty = call_method_if_valid(comp, "MarkRenderDynamicDataDirty")
		end
		if not ok_dirty then
			ok_dirty = call_method_if_valid(comp, "MarkRenderTransformDirty")
		end
		if not ok_dirty then
			ok_dirty = call_method_if_valid(comp, "ReregisterComponent")
		end
		if not ok_dirty then
			ok_dirty = call_method_if_valid(comp, "RecreateRenderState_Concurrent")
		end

		if ok_dirty then
			STATE.mesh_render_state_dirty_last = STATE.mesh_render_state_dirty_last + 1
		else
			STATE.mesh_render_state_dirty_fail_last = STATE.mesh_render_state_dirty_fail_last + 1
		end
	end

	if CONFIG.mesh_fix_black_materials then
		if try_fix_wall_materials(comp, entry) then
			changed_any = true
		end
	end

	if CONFIG.mesh_force_material_name ~= "" then
		if try_force_material(comp, entry) then
			changed_any = true
		end
	end

	if CONFIG.mesh_disable_world_position_offset then
		if set_number_property_confirmed(comp, "WorldPositionOffsetDisableDistance", 0.0, nil) then
			changed_any = true
		end
	end

	entry.patched = changed_any
	return changed_any
end

local function patch_cached_mesh_components(force_reapply)
	STATE.mesh_components_patched_last = 0
	STATE.mesh_write_fail_last = 0
	STATE.mesh_filter_skipped_last = 0
	STATE.mesh_scope_skipped_last = 0
	STATE.mesh_force_apply_ops_last = 0
	STATE.mesh_cull_distance_ops_last = 0
	STATE.mesh_cull_distance_fail_last = 0
	STATE.mesh_bounds_scale_ops_last = 0
	STATE.mesh_bounds_scale_fail_last = 0
	STATE.mesh_pseudo_thickness_ops_last = 0
	STATE.mesh_pseudo_thickness_fail_last = 0
	STATE.mesh_lumen_cache_invalidations_last = 0
	STATE.mesh_lumen_cache_invalidation_fail_last = 0
	STATE.mesh_render_state_dirty_last = 0
	STATE.mesh_render_state_dirty_fail_last = 0

	if force_reapply then
		for _, entry in pairs(STATE.mesh_entries) do
			entry.patched = false
		end
	end

	local patched_now = 0
	for _, entry in pairs(STATE.mesh_entries) do
		if (not force_reapply) and entry.patched then
			-- keep prior patch unless explicit reapply requested
		elseif patch_mesh_entry(entry) then
			patched_now = patched_now + 1
		end
	end

	STATE.mesh_components_patched_last = patched_now
	STATE.mesh_components_patched_total = count_mesh_patched_total()
end

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
	CONFIG = tg_config.CONFIG
	STATE = tg_state.STATE
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
	-- normalize_config is in main.lua; caller should call normalize_config after updating CONFIG

	local shown = table.concat(CONFIG.mesh_name_filters, ",")
	if shown == "" then
		shown = "<none>"
	end

	log(string.format("mesh filters set count=%d values=%s", #CONFIG.mesh_name_filters, shown))
end

local function set_mesh_scope_include_filters(parameters)
	CONFIG.mesh_scope_include_filters = parse_filter_tokens(parameters)
	local shown = table.concat(CONFIG.mesh_scope_include_filters, ",")
	if shown == "" then
		shown = "<none>"
	end
	log(string.format("mesh scope include set count=%d values=%s", #CONFIG.mesh_scope_include_filters, shown))
end

local function set_mesh_scope_exclude_filters(parameters)
	CONFIG.mesh_scope_exclude_filters = parse_filter_tokens(parameters)
	local shown = table.concat(CONFIG.mesh_scope_exclude_filters, ",")
	if shown == "" then
		shown = "<none>"
	end
	log(string.format("mesh scope exclude set count=%d values=%s", #CONFIG.mesh_scope_exclude_filters, shown))
end

M.get_target_mesh_component_classes = get_target_mesh_component_classes
M.normalize_axis_name = normalize_axis_name
M.try_apply_pseudo_thickness = try_apply_pseudo_thickness
M.contains_any_name_filter = contains_any_name_filter
M.matches_filter_with_basename = matches_filter_with_basename
M.contains_any_scope_include = contains_any_scope_include
M.matches_any_scope_exclude = matches_any_scope_exclude
M.get_mesh_candidate_rejection_reason = get_mesh_candidate_rejection_reason
M.is_mesh_component_candidate = is_mesh_component_candidate
M.refresh_mesh_cache = refresh_mesh_cache
M.count_mesh_patched_total = count_mesh_patched_total
M.patch_mesh_entry = patch_mesh_entry
M.patch_cached_mesh_components = patch_cached_mesh_components
M.parse_mesh_find_request = parse_mesh_find_request
M.parse_filter_tokens = parse_filter_tokens
M.run_mesh_find = run_mesh_find
M.set_mesh_filters = set_mesh_filters
M.set_mesh_scope_include_filters = set_mesh_scope_include_filters
M.set_mesh_scope_exclude_filters = set_mesh_scope_exclude_filters
M.try_fix_wall_materials = try_fix_wall_materials
M.try_force_material = try_force_material

return M
