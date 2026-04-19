local function require_module(name, marker)
	if type(require) ~= "function" then
		return nil, "require unavailable"
	end

	local ok, mod = pcall(require, name)
	if not ok then
		return nil, tostring(mod)
	end

	if type(mod) ~= "table" then
		return nil, "module is not a table"
	end

	if marker ~= nil and mod.__tajsgraph_module ~= marker then
		return nil, "unexpected module marker"
	end

	return mod, nil
end

local log_module, log_err = require_module("rt_log", "rt_log")
if not log_module then
	error("failed to load module 'rt_log': " .. tostring(log_err))
end

local config_module, config_err = require_module("config", "config")
if not config_module then
	error("failed to load module 'config': " .. tostring(config_err))
end

local coordinator_module, runtime_err = require_module("rt_coordinator", "rt_coordinator")
if not coordinator_module then
	error("failed to load module 'rt_coordinator': " .. tostring(runtime_err))
end

local log = log_module.log
local CONFIG = config_module.normalize({})
local runtime = coordinator_module.new_runtime(CONFIG)
local SHARED = rawget(_G, "__tajsgraphbm_shared")
if type(SHARED) ~= "table" then
	SHARED = {}
	rawset(_G, "__tajsgraphbm_shared", SHARED)
end
SHARED.reload_generation = (tonumber(SHARED.reload_generation) or 0) + 1
SHARED.runtime = runtime

local function safe_run(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		runtime.state.stats.last_error = tostring(err)
		log(string.format("%s failed: %s", name, runtime.state.stats.last_error))
		return false
	end
	return true
end

local function register_commands()
	local register_command = nil
	local backend = nil
	if type(RegisterConsoleCommandHandler) == "function" then
		register_command = RegisterConsoleCommandHandler
		backend = "RegisterConsoleCommandHandler"
	elseif type(RegisterConsoleCommandGlobalHandler) == "function" then
		register_command = RegisterConsoleCommandGlobalHandler
		backend = "RegisterConsoleCommandGlobalHandler"
	end

	if type(register_command) ~= "function" then
		log("console command handler unavailable")
		return
	end

	local function dispatch_command(cmd, parts)
		local cmd_lower = string.lower(tostring(cmd or ""))
		local part1 = ""
		if type(parts) == "table" and #parts >= 1 then
			part1 = string.lower(tostring(parts[1] or ""))
		end

		local action = nil
		local action_name = nil

		if cmd_lower == "tajsgraph.apply" or cmd_lower == "tajsgraph_apply" then
			action_name = "tajsgraph.apply"
			action = function()
				runtime.apply(true, "command")
			end
		elseif cmd_lower == "tajsgraph.status" or cmd_lower == "tajsgraph_status" then
			action_name = "tajsgraph.status"
			action = function()
				runtime.print_status()
			end
		elseif cmd_lower == "tajsgraph.rebaseline" or cmd_lower == "tajsgraph_rebaseline" then
			action_name = "tajsgraph.rebaseline"
			action = function()
				runtime.rebaseline()
			end
		elseif cmd_lower == "tajsgraph" then
			if part1 == "apply" then
				action_name = "tajsgraph.apply"
				action = function()
					runtime.apply(true, "command")
				end
			elseif part1 == "status" then
				action_name = "tajsgraph.status"
				action = function()
					runtime.print_status()
				end
			elseif part1 == "rebaseline" then
				action_name = "tajsgraph.rebaseline"
				action = function()
					runtime.rebaseline()
				end
			end
		end

		if action == nil then
			return false
		end

		safe_run(action_name, action)
		-- Return true for matched commands even when execution failed, so UE does not
		-- treat a known command as unrecognized.
		return true
	end

	SHARED.command_dispatch = dispatch_command

	local function command_wrapper(cmd, parts, ar)
		local _ = ar
		local ok, handled_or_err = pcall(function()
			local dispatch = SHARED.command_dispatch
			if type(dispatch) ~= "function" then
				return false
			end
			return dispatch(cmd, parts)
		end)
		if not ok then
			runtime.state.stats.last_error = tostring(handled_or_err)
			log("command dispatch failed: " .. runtime.state.stats.last_error)
			return false
		end

		local handled = handled_or_err == true
		if CONFIG.diagnostic_logging then
			log(string.format(
				"diag cmd in=%s handled=%s",
				tostring(cmd),
				tostring(handled)
			))
		end
		if handled then
			return true
		end
		return false
	end

	if SHARED.commands_registered == true then
		log("diag commands already registered; dispatcher refreshed for hot reload")
		return
	end

	register_command("tajsgraph", command_wrapper)
	register_command("tajsgraph.apply", command_wrapper)
	register_command("tajsgraph.status", command_wrapper)
	register_command("tajsgraph.rebaseline", command_wrapper)
	register_command("tajsgraph_apply", command_wrapper)
	register_command("tajsgraph_status", command_wrapper)
	register_command("tajsgraph_rebaseline", command_wrapper)
	SHARED.commands_registered = true

	log(string.format(
		"diag commands registered via %s: tajsgraph[.apply|.status|.rebaseline] (+ underscore aliases)",
		tostring(backend)
	))
end

local function register_transition_hooks()
	if CONFIG.auto_apply_on_transition ~= true then
		log("diag transition auto-apply disabled")
		return
	end

	if type(RegisterInitGameStatePostHook) == "function" then
		log("diag hook RegisterInitGameStatePostHook active")
		RegisterInitGameStatePostHook(function()
			safe_run("InitGameStatePostHook", function()
				runtime.schedule_apply("init_game_state")
			end)
		end)
	else
		log("diag hook RegisterInitGameStatePostHook unavailable")
	end

	-- Some games do not expose Engine::LoadMap as a hookable UFunction in UE4SS.
	-- Skip registering it to avoid startup error spam.
end

local function register_spawn_listener()
	if CONFIG.auto_apply_on_spawn ~= true then
		log("diag spawn auto-apply disabled")
		return
	end

	if type(NotifyOnNewObject) ~= "function" then
		log("NotifyOnNewObject unavailable; spawn listener disabled")
		return
	end

	log("diag hook NotifyOnNewObject SpotLightComponent active")
	NotifyOnNewObject("/Script/Engine.SpotLightComponent", function(new_object)
		safe_run("NotifyOnNewObject SpotLightComponent", function()
			runtime.on_spotlight_spawned(new_object)
		end)
	end)
end

register_commands()
register_transition_hooks()
register_spawn_listener()
log(string.format(
	"diag config tune_enabled=%s mode=%s runtime_compat=%s movable=%s mobility=%d cast=%s visible=%s",
	tostring(CONFIG.spotlight_tune_enabled),
	tostring(CONFIG.spotlight_tune_mode),
	tostring(CONFIG.spotlight_runtime_compat_enabled),
	tostring(CONFIG.spotlight_runtime_force_movable),
	tonumber(CONFIG.spotlight_runtime_mobility_value or -1),
	tostring(CONFIG.spotlight_runtime_force_cast_shadows),
	tostring(CONFIG.spotlight_runtime_force_visible_enabled)
))
log(string.format(
	"diag config auto startup=%s followup=%s transition=%s spawn=%s backup_loop=%s",
	tostring(CONFIG.auto_apply_on_startup),
	tostring(CONFIG.auto_apply_startup_followup),
	tostring(CONFIG.auto_apply_on_transition),
	tostring(CONFIG.auto_apply_on_spawn),
	tostring(CONFIG.auto_backup_loop)
))
log(string.format(
	"diag config post_apply_vsm enabled=%s rebaseline=%s off=%d on=%d delay_ms=%d",
	tostring(CONFIG.post_apply_vsm_reload_enabled),
	tostring(CONFIG.post_apply_vsm_reload_on_rebaseline),
	tonumber(CONFIG.post_apply_vsm_reload_off_value or -1),
	tonumber(CONFIG.post_apply_vsm_reload_on_value or -1),
	tonumber(CONFIG.post_apply_vsm_reload_delay_ms or -1)
))
if CONFIG.auto_backup_loop == true then
	runtime.start_backup_loop()
else
	log("diag backup loop disabled")
end

if CONFIG.auto_apply_on_startup == true then
	runtime.apply(true, "startup")
	if CONFIG.auto_apply_startup_followup == true and type(runtime.schedule_apply) == "function" then
		if type(ExecuteInGameThreadWithDelay) == "function" then
			ExecuteInGameThreadWithDelay(CONFIG.startup_followup_delay_ms, function()
				safe_run("startup_followup", function()
					runtime.apply(true, "startup_followup")
				end)
			end)
		elseif type(ExecuteWithDelay) == "function" then
			ExecuteWithDelay(CONFIG.startup_followup_delay_ms, function()
				safe_run("startup_followup", function()
					runtime.apply(true, "startup_followup")
				end)
			end)
		end
	end
else
	log("diag startup auto-apply disabled (use tajsgraph.apply)")
end
log("loaded (spotlights + megalights + lumen)")
