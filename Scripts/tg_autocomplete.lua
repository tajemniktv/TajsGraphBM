local M = {}

local utils, state_mod, config_mod = nil, nil, nil
if type(require) == "function" then
	local ok_utils, u = pcall(require, "tg_utils")
	if ok_utils and type(u) == "table" then
		utils = u
	end
	local ok_state, s = pcall(require, "tg_state")
	if ok_state and type(s) == "table" then
		state_mod = s
	end
	local ok_config, c = pcall(require, "tg_config")
	if ok_config and type(c) == "table" then
		config_mod = c
	end
end
if not utils or not state_mod or not config_mod then
	error("tg_autocomplete: missing dependency (tg_utils/tg_state/tg_config)")
end

local STATE = state_mod.STATE
local CONFIG = config_mod.CONFIG

local log = function(msg)
	print(tostring(msg))
end
function M.set_logger(fn)
	if type(fn) == "function" then
		log = fn
	end
end

local function trim(s)
	if type(s) ~= "string" then
		return ""
	end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalize_dump_path(path)
	if type(path) ~= "string" then
		return ""
	end
	return path:gsub("\\", "/")
end

local function parse_cvar_dump_linewise(path)
	local normalized_path = normalize_dump_path(path)
	local file, open_err = io.open(normalized_path, "r")
	if file == nil then
		return false, {}, string.format("open failed: %s", tostring(open_err))
	end

	local parsed = {}
	local current = nil

	for line in file:lines() do
		local key = line:match('^%s*"([^"]+)"%s*:%s*{%s*$')
		if key ~= nil then
			current = { name = key, ctype = "Unknown", help = "" }
		elseif current ~= nil then
			local ctype = line:match('^%s*"type"%s*:%s*"([^"]+)"')
			if ctype ~= nil then
				current.ctype = ctype
			end

			local help = line:match('^%s*"Helptext"%s*:%s*"(.*)"%s*,?%s*$')
			if help ~= nil then
				current.help = help
			end

			if line:match('^%s*}%s*,?%s*$') then
				parsed[#parsed + 1] = current
				current = nil
			end
		end
	end

	file:close()
	return true, parsed, ""
end

local function build_autocomplete_candidates(entries)
	local candidates = {}
	for _, item in ipairs(entries) do
		if type(item.name) == "string" and item.name ~= "" then
			local desc = string.format("[%s] %s", tostring(item.ctype or "Unknown"), trim(item.help or ""))
			candidates[#candidates + 1] = {
				Command = item.name,
				Desc = trim(desc),
				ctype = item.ctype,
			}
		end
	end

	table.sort(candidates, function(a, b)
		local at = tostring(a.ctype or "")
		local bt = tostring(b.ctype or "")
		if at == "Command" and bt ~= "Command" then
			return true
		end
		if bt == "Command" and at ~= "Command" then
			return false
		end

		return tostring(a.Command) < tostring(b.Command)
	end)

	return candidates
end

local function get_console_settings()
	if type(StaticFindObject) ~= "function" then
		return nil
	end

	local paths = {
		"/Script/EngineSettings.Default__ConsoleSettings",
		"Default__ConsoleSettings",
		"/Script/EngineSettings.ConsoleSettings",
	}

	for _, path in ipairs(paths) do
		local ok, obj = pcall(function()
			return StaticFindObject(path)
		end)
		if ok and utils and utils.is_valid(obj) then
			return obj
		end
	end

	local all_settings = {}
	if utils then
		all_settings = utils.get_objects_of_class and utils.get_objects_of_class("ConsoleSettings") or {}
	end
	if #all_settings > 0 and utils.is_valid(all_settings[1]) then
		return all_settings[1]
	end

	return nil
end

local function write_autocomplete_tarray(array_obj, candidates)
	if array_obj == nil then
		return false, 0, 0, "array unavailable"
	end

	local before_count = 0
	pcall(function()
		before_count = #array_obj
	end)

	local ok_empty = pcall(function()
		array_obj:Empty()
	end)
	if not ok_empty then
		return false, before_count, before_count, "array:Empty failed"
	end

	local max_entries = CONFIG.autocomplete_max_entries
	if type(max_entries) ~= "number" or max_entries < 1 then
		max_entries = 10000
	end
	max_entries = math.floor(max_entries)

	local applied = 0
	for _, candidate in ipairs(candidates) do
		if applied >= max_entries then
			break
		end

		local value = { Command = candidate.Command, Desc = candidate.Desc }
		local wrote = false

		local index_one_based = applied + 1
		if pcall(function()
				array_obj[index_one_based] = value
			end) then
			wrote = true
		end

		if not wrote then
			local index_zero_based = applied
			if pcall(function()
					array_obj[index_zero_based] = value
				end) then
				wrote = true
			end
		end

		if not wrote and type(array_obj.Add) == "function" then
			if pcall(function()
					array_obj:Add(value)
				end) then
				wrote = true
			end
		end

		if not wrote then
			if applied == 0 then
				return false, before_count, before_count, "Failed to insert first autocomplete entry"
			end
			break
		end

		applied = applied + 1
	end

	local after_count = before_count
	pcall(function()
		after_count = #array_obj
	end)

	if applied == 0 then
		return false, before_count, after_count, "No autocomplete entries were inserted"
	end

	return true, before_count, after_count, ""
end

local function write_manual_autocomplete_list(settings_obj, candidates)
	if settings_obj == nil or not utils.is_valid(settings_obj) then
		return false, 0, 0, "ConsoleSettings not found"
	end

	local ok_list, manual_list = utils.get_field(settings_obj, "ManualAutoCompleteList")
	if not ok_list or manual_list == nil then
		return false, 0, 0, "ManualAutoCompleteList unavailable"
	end

	return write_autocomplete_tarray(manual_list, candidates)
end

local function write_runtime_autocomplete_list(console_obj, candidates)
	if console_obj == nil or not utils.is_valid(console_obj) then
		return false, 0, 0, "Console unavailable"
	end

	local ok_list, runtime_list = utils.get_field(console_obj, "AutoCompleteList")
	if not ok_list or runtime_list == nil then
		return false, 0, 0, "AutoCompleteList unavailable"
	end

	return write_autocomplete_tarray(runtime_list, candidates)
end

local function mark_runtime_autocomplete_dirty()
	local updated = 0
	local consoles = utils.get_objects_of_class and utils.get_objects_of_class("Console") or {}
	for _, console in ipairs(consoles) do
		if utils.is_valid(console) then
			utils.set_field(console, "bIsRuntimeAutoCompleteUpToDate", false)
			utils.call_method_if_valid(console, "BuildRuntimeAutoCompleteList")
			utils.call_method_if_valid(console, "BuildRuntimeAutoCompleteList", true)
			utils.call_method_if_valid(console, "BuildRuntimeAutoCompleteList", false)
			updated = updated + 1
		end
	end

	STATE.autocomplete_console_marked = updated
	return updated
end

local function load_autocomplete_data()
	STATE.autocomplete_loaded = false
	STATE.autocomplete_load_error = ""
	STATE.autocomplete_parse_count = 0
	STATE.autocomplete_top_results = {}
	STATE.autocomplete_candidates = {}

	local ok, parsed, err = parse_cvar_dump_linewise(CONFIG.autocomplete_dump_path)
	if not ok then
		STATE.autocomplete_load_error = err
		return false
	end

	local candidates = build_autocomplete_candidates(parsed)
	STATE.autocomplete_parse_count = #candidates
	STATE.autocomplete_candidates = candidates
	STATE.autocomplete_loaded = true

	for i = 1, math.min(8, #candidates) do
		STATE.autocomplete_top_results[#STATE.autocomplete_top_results + 1] = candidates[i].Command
	end

	return true
end

local function escape_ini_string(value)
	local s = tostring(value or "")
	s = s:gsub("\\", "\\\\")
	s = s:gsub('"', '\\"')
	s = s:gsub("\r", " ")
	s = s:gsub("\n", " ")
	return s
end

local function detect_input_ini_path()
	if type(CONFIG.autocomplete_input_ini_path) == "string" and CONFIG.autocomplete_input_ini_path ~= "" then
		return normalize_dump_path(CONFIG.autocomplete_input_ini_path)
	end

	local local_app_data = os.getenv("LOCALAPPDATA")
	if type(local_app_data) == "string" and local_app_data ~= "" then
		return normalize_dump_path(local_app_data .. "/BetterMart/Saved/Config/Windows/Input.ini")
	end

	return "C:/Users/tajem/AppData/Local/BetterMart/Saved/Config/Windows/Input.ini"
end

local function apply_autocomplete_entries()
	STATE.autocomplete_applied = false
	STATE.autocomplete_last_apply_error = ""
	STATE.autocomplete_manual_before = 0
	STATE.autocomplete_manual_after = 0
	STATE.autocomplete_applied_count = 0
	STATE.autocomplete_runtime_before = 0
	STATE.autocomplete_runtime_after = 0
	STATE.autocomplete_runtime_applied_count = 0

	if not CONFIG.autocomplete_enabled then
		STATE.autocomplete_last_apply_error = "disabled by config"
		return false
	end

	if not STATE.autocomplete_loaded then
		if not load_autocomplete_data() then
			STATE.autocomplete_last_apply_error = STATE.autocomplete_load_error
			return false
		end
	end

	local settings_obj = get_console_settings()
	local ok_write_manual, before_count_manual, after_count_manual, write_err_manual = write_manual_autocomplete_list(
		settings_obj, STATE.autocomplete_candidates)
	STATE.autocomplete_manual_before = before_count_manual or 0
	STATE.autocomplete_manual_after = after_count_manual or 0

	local runtime_apply_ok = false
	local runtime_before = 0
	local runtime_after = 0
	local runtime_applied = 0
	local runtime_error = ""
	local consoles = utils.get_objects_of_class and utils.get_objects_of_class("Console") or {}
	for _, console in ipairs(consoles) do
		if utils.is_valid(console) then
			local ok_runtime, before_count_runtime, after_count_runtime, write_err_runtime =
				write_runtime_autocomplete_list(console, STATE.autocomplete_candidates)
			if ok_runtime then
				runtime_apply_ok = true
				runtime_before = before_count_runtime or runtime_before
				runtime_after = after_count_runtime or runtime_after
				runtime_applied = runtime_applied + 1
			elseif runtime_error == "" then
				runtime_error = tostring(write_err_runtime)
			end
		end
	end

	STATE.autocomplete_runtime_before = runtime_before
	STATE.autocomplete_runtime_after = runtime_after
	STATE.autocomplete_runtime_applied_count = runtime_applied

	if ok_write_manual and not runtime_apply_ok and runtime_error ~= "" then
		STATE.autocomplete_last_apply_error = string.format("runtime_only_warning=%s", runtime_error)
	end

	if not ok_write_manual and not runtime_apply_ok then
		if runtime_error ~= "" then
			STATE.autocomplete_last_apply_error = string.format("manual=%s | runtime=%s", tostring(write_err_manual),
				runtime_error)
		else
			STATE.autocomplete_last_apply_error = tostring(write_err_manual)
		end
		return false
	end

	local hard_cap = CONFIG.autocomplete_max_entries
	if type(hard_cap) ~= "number" or hard_cap < 1 then
		hard_cap = #STATE.autocomplete_candidates
	end
	hard_cap = math.floor(hard_cap)

	STATE.autocomplete_applied_count = math.min(#STATE.autocomplete_candidates, hard_cap)
	STATE.autocomplete_applied = true
	mark_runtime_autocomplete_dirty()
	return true
end

local function run_autocomplete_status()
	log(string.format(
		"autocomplete enabled=%s loaded=%s parse_count=%d applied=%s applied_count=%d manual_before=%d manual_after=%d runtime_before=%d runtime_after=%d runtime_consoles=%d console_marked=%d",
		tostring(CONFIG.autocomplete_enabled),
		tostring(STATE.autocomplete_loaded),
		STATE.autocomplete_parse_count,
		tostring(STATE.autocomplete_applied),
		STATE.autocomplete_applied_count,
		STATE.autocomplete_manual_before,
		STATE.autocomplete_manual_after,
		STATE.autocomplete_runtime_before,
		STATE.autocomplete_runtime_after,
		STATE.autocomplete_runtime_applied_count,
		STATE.autocomplete_console_marked
	))

	if STATE.autocomplete_load_error ~= "" then
		log(string.format("autocomplete load_error=%s", STATE.autocomplete_load_error))
	end
	if STATE.autocomplete_last_apply_error ~= "" then
		log(string.format("autocomplete apply_error=%s", STATE.autocomplete_last_apply_error))
	end

	if #STATE.autocomplete_top_results > 0 then
		log(string.format("autocomplete sample=%s", table.concat(STATE.autocomplete_top_results, ", ")))
	end
end

local function run_autocomplete_probe()
	local console_count = 0
	local consoles = utils.get_objects_of_class and utils.get_objects_of_class("Console") or {}
	for _, console in ipairs(consoles) do
		if utils.is_valid(console) then
			console_count = console_count + 1

			local full_name = "<unknown>"
			pcall(function()
				full_name = console:GetFullName()
			end)

			local has_runtime_list, runtime_list = utils.get_field(console, "AutoCompleteList")
			local runtime_count = -1
			if has_runtime_list and runtime_list ~= nil then
				pcall(function()
					runtime_count = #runtime_list
				end)
			end

			local has_dirty, dirty_value = utils.get_field(console, "bIsRuntimeAutoCompleteUpToDate")
			local build_noargs = utils.call_method_if_valid(console, "BuildRuntimeAutoCompleteList")
			local build_true = utils.call_method_if_valid(console, "BuildRuntimeAutoCompleteList", true)
			local build_false = utils.call_method_if_valid(console, "BuildRuntimeAutoCompleteList", false)

			log(string.format(
				"autocomplete probe console=%s runtime_list=%s runtime_count=%d dirty_field=%s dirty_value=%s build_noargs=%s build_true=%s build_false=%s",
				tostring(full_name),
				tostring(has_runtime_list and runtime_list ~= nil),
				runtime_count,
				tostring(has_dirty),
				tostring(dirty_value),
				tostring(build_noargs),
				tostring(build_true),
				tostring(build_false)
			))
		end
	end

	local settings_obj = get_console_settings()
	local has_settings = (settings_obj ~= nil and utils.is_valid(settings_obj))
	local settings_count = -1
	if has_settings then
		local ok_list, manual_list = utils.get_field(settings_obj, "ManualAutoCompleteList")
		if ok_list and manual_list ~= nil then
			pcall(function()
				settings_count = #manual_list
			end)
		end
	end

	log(string.format("autocomplete probe consoles=%d settings_found=%s settings_manual_count=%d", console_count,
		tostring(has_settings), settings_count))
end

local function run_autocomplete_apply()
	if apply_autocomplete_entries() then
		log(string.format(
			"autocomplete apply ok entries=%d manual_after=%d runtime_after=%d runtime_consoles=%d console_marked=%d",
			STATE.autocomplete_applied_count, STATE.autocomplete_manual_after, STATE.autocomplete_runtime_after,
			STATE.autocomplete_runtime_applied_count, STATE.autocomplete_console_marked))
	else
		log(string.format("autocomplete apply failed: %s", tostring(STATE.autocomplete_last_apply_error)))
	end
end

local function run_autocomplete_reload()
	if not load_autocomplete_data() then
		log(string.format("autocomplete load failed: %s", tostring(STATE.autocomplete_load_error)))
		return
	end

	run_autocomplete_apply()
end

local function run_autocomplete_suggest(parameters)
	local query = ""
	if type(parameters) == "table" and type(parameters[1]) == "string" then
		query = string.lower(trim(parameters[1]))
	end

	if not STATE.autocomplete_loaded then
		if not load_autocomplete_data() then
			log(string.format("autocomplete suggest load failed: %s", tostring(STATE.autocomplete_load_error)))
			return
		end
	end

	local cap = 15
	local shown = 0
	log(string.format("autocomplete suggest query='%s'", query))
	for _, candidate in ipairs(STATE.autocomplete_candidates) do
		local cmd = tostring(candidate.Command or "")
		local lower = string.lower(cmd)
		local match = query == "" or string.find(lower, query, 1, true) ~= nil
		if match then
			shown = shown + 1
			log(string.format("  %s - %s", candidate.Command, candidate.Desc))
			if shown >= cap then
				break
			end
		end
	end

	if shown == 0 then
		log(string.format("autocomplete suggest no matches for '%s'", query))
	end
end

local function export_autocomplete_to_input_ini()
	if not STATE.autocomplete_loaded then
		if not load_autocomplete_data() then
			log(string.format("autocomplete export failed: %s", tostring(STATE.autocomplete_load_error)))
			return
		end
	end

	local input_ini_path = detect_input_ini_path()
	local in_file, in_err = io.open(input_ini_path, "r")
	local existing_lines = {}
	if in_file ~= nil then
		for line in in_file:lines() do
			existing_lines[#existing_lines + 1] = line
		end
		in_file:close()
	elseif in_err ~= nil then
		log(string.format("autocomplete export: reading existing Input.ini failed (%s), writing new file",
			tostring(in_err)))
	end

	local filtered_lines = {}
	local skip_section = false
	for _, line in ipairs(existing_lines) do
		local section_name = line:match("^%s*%[(.-)%]%s*$")
		if section_name ~= nil then
			local lower = string.lower(section_name)
			if lower == "/script/enginesettings.consolesettings" then
				skip_section = true
			else
				skip_section = false
				filtered_lines[#filtered_lines + 1] = line
			end
		elseif not skip_section then
			filtered_lines[#filtered_lines + 1] = line
		end
	end

	filtered_lines[#filtered_lines + 1] = ""
	filtered_lines[#filtered_lines + 1] = "[/Script/EngineSettings.ConsoleSettings]"
	filtered_lines[#filtered_lines + 1] = "bDisplayHelpInAutoComplete=True"

	local hard_cap = CONFIG.autocomplete_max_entries
	if type(hard_cap) ~= "number" or hard_cap < 1 then
		hard_cap = #STATE.autocomplete_candidates
	end
	hard_cap = math.floor(hard_cap)

	local exported = 0
	for _, candidate in ipairs(STATE.autocomplete_candidates) do
		if exported >= hard_cap then
			break
		end

		local command = escape_ini_string(candidate.Command)
		local desc = escape_ini_string(candidate.Desc)
		filtered_lines[#filtered_lines + 1] = string.format('+ManualAutoCompleteList=(Command="%s",Desc="%s")', command,
			desc)
		exported = exported + 1
	end

	local out_file, out_err = io.open(input_ini_path, "w")
	if out_file == nil then
		log(string.format("autocomplete export failed: %s", tostring(out_err)))
		return
	end

	out_file:write(table.concat(filtered_lines, "\n"))
	out_file:write("\n")
	out_file:close()

	log(string.format("autocomplete export ok path=%s entries=%d", input_ini_path, exported))
	log("restart the game to ensure ConsoleSettings autocomplete is rebuilt from Input.ini")
end

M.set_logger = M.set_logger
M.run_autocomplete_status = run_autocomplete_status
M.run_autocomplete_probe = run_autocomplete_probe
M.run_autocomplete_apply = run_autocomplete_apply
M.run_autocomplete_reload = run_autocomplete_reload
M.run_autocomplete_suggest = run_autocomplete_suggest
M.export_autocomplete_to_input_ini = export_autocomplete_to_input_ini
M.trim = trim
M.normalize_dump_path = normalize_dump_path

return M
