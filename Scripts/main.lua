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

local config_store_module, config_store_err = require_module("config_store", "config_store")
if not config_store_module then
    error("failed to load module 'config_store': " .. tostring(config_store_err))
end

local coordinator_module, runtime_err = require_module("rt_coordinator", "rt_coordinator")
if not coordinator_module then
    error("failed to load module 'rt_coordinator': " .. tostring(runtime_err))
end

local log = log_module.log
local SHARED = rawget(_G, "__tajsgraphbm_shared")
if type(SHARED) ~= "table" then
    SHARED = {}
    rawset(_G, "__tajsgraphbm_shared", SHARED)
end

local function format_value(value)
    if type(value) == "string" then
        return string.format("%q", value)
    end
    if type(value) == "boolean" then
        return value and "true" or "false"
    end
    return tostring(value)
end

local function parse_bool_token(raw)
    local token = string.lower(tostring(raw or ""))
    if token == "1" or token == "true" or token == "on" or token == "yes" then
        return true
    end
    if token == "0" or token == "false" or token == "off" or token == "no" then
        return false
    end
    return nil
end

local function load_config_from_store()
    local overrides, load_err = config_store_module.load_user_overrides()
    if load_err ~= nil then
        log("ui reload warning: " .. tostring(load_err))
    end

    if type(overrides) ~= "table" then
        overrides = {}
    end
    return config_module.normalize(overrides)
end

local CONFIG = load_config_from_store()
local runtime = coordinator_module.new_runtime(CONFIG)

SHARED.reload_generation = (tonumber(SHARED.reload_generation) or 0) + 1
SHARED.runtime = runtime

local BOOL_KEY_SET = {}
for _, key in ipairs(config_module.bool_keys or {}) do
    BOOL_KEY_SET[key] = true
end

local NUMERIC_KEY_SET = {}
for _, key in ipairs(config_module.numeric_keys or {}) do
    NUMERIC_KEY_SET[key] = true
end

local function coerce_config_value(key, raw_value)
    if NUMERIC_KEY_SET[key] == true then
        local parsed = tonumber(raw_value)
        if type(parsed) ~= "number" then
            return nil, "expected number"
        end
        return parsed, nil
    end

    if BOOL_KEY_SET[key] == true then
        local parsed = parse_bool_token(raw_value)
        if type(parsed) ~= "boolean" then
            return nil, "expected boolean (true/false/1/0/on/off)"
        end
        return parsed, nil
    end

    if key == "spotlight_tune_mode" then
        local mode = string.lower(tostring(raw_value or ""))
        if mode ~= "multiplier" and mode ~= "absolute" then
            return nil, "expected 'multiplier' or 'absolute'"
        end
        return mode, nil
    end

    return nil, "unsupported key type"
end

local function safe_run(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        runtime.state.stats.last_error = tostring(err)
        log(string.format("%s failed: %s", name, runtime.state.stats.last_error))
        return false
    end
    return true
end

local function persist_config_to_disk()
    local ok_save, save_err = config_store_module.save_user_overrides(CONFIG, config_module.defaults or {})
    if not ok_save then
        return false, save_err
    end
    return true, nil
end

local function update_runtime_config(next_config)
    local normalized = config_module.normalize(next_config or {})
    local ok_set, set_err = runtime.set_config(normalized)
    if not ok_set then
        return false, tostring(set_err)
    end
    CONFIG = normalized
    SHARED.runtime = runtime
    return true, nil
end

local function ui_get(args)
    local key = tostring(args[1] or "")
    if not config_module.is_known_key(key) then
        return false, "unknown key '" .. key .. "'"
    end

    log(string.format("ui.get ok key=%s value=%s", key, format_value(CONFIG[key])))
    return true, nil
end

local function ui_set(args)
    local key = tostring(args[1] or "")
    local value_token = args[2]
    if not config_module.is_known_key(key) then
        return false, "unknown key '" .. key .. "'"
    end
    if value_token == nil then
        return false, "missing value"
    end

    local value, coerce_err = coerce_config_value(key, value_token)
    if coerce_err ~= nil then
        return false, string.format("invalid value for %s: %s", key, coerce_err)
    end

    local next_config = {}
    for cfg_key, cfg_value in pairs(CONFIG) do
        next_config[cfg_key] = cfg_value
    end
    next_config[key] = value

    local ok_update, update_err = update_runtime_config(next_config)
    if not ok_update then
        return false, "failed to update runtime config: " .. tostring(update_err)
    end

    log(string.format("ui.set ok key=%s value=%s", key, format_value(CONFIG[key])))
    return true, nil
end

local function ui_apply()
    local ok = runtime.apply(true, "command")
    if not ok then
        return false, "runtime.apply returned false"
    end
    log("ui.apply ok")
    return true, nil
end

local function ui_reload()
    local loaded = load_config_from_store()
    local ok_update, update_err = update_runtime_config(loaded)
    if not ok_update then
        return false, "failed to replace runtime config: " .. tostring(update_err)
    end

    local ok = runtime.apply(true, "command")
    if not ok then
        return false, "runtime.apply returned false after reload"
    end

    log("ui.reload ok")
    return true, nil
end

local function ui_save()
    local ok_save, save_err = persist_config_to_disk()
    if not ok_save then
        return false, "failed to save user config: " .. tostring(save_err)
    end
    log("ui.save ok path=" .. tostring(config_store_module.get_user_config_path()))
    return true, nil
end

local function ui_reset_core()
    local next_config = {}
    for cfg_key, cfg_value in pairs(CONFIG) do
        next_config[cfg_key] = cfg_value
    end
    for _, key in ipairs(config_module.core_ui_keys or {}) do
        next_config[key] = config_module.defaults[key]
    end

    local ok_update, update_err = update_runtime_config(next_config)
    if not ok_update then
        return false, "failed to reset core config: " .. tostring(update_err)
    end

    local ok = runtime.apply(true, "command")
    if not ok then
        return false, "runtime.apply returned false after reset_core"
    end

    log("ui.reset_core ok")
    return true, nil
end

local function ui_status()
    log("ui.status begin")
    log("ui.status config_path=" .. tostring(config_store_module.get_user_config_path()))
    for _, key in ipairs(config_module.core_ui_keys or {}) do
        log(string.format("ui.status core %s=%s", key, format_value(CONFIG[key])))
    end
    runtime.print_status()
    log("ui.status end")
    return true, nil
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

    local function slice_parts(parts, start_index)
        local out = {}
        if type(parts) ~= "table" then
            return out
        end
        local index = math.max(1, math.floor(tonumber(start_index) or 1))
        while parts[index] ~= nil do
            out[#out + 1] = tostring(parts[index])
            index = index + 1
        end
        return out
    end

    local function dispatch_command(cmd, parts)
        local cmd_lower = string.lower(tostring(cmd or ""))
        local part1 = ""
        if type(parts) == "table" and #parts >= 1 then
            part1 = string.lower(tostring(parts[1] or ""))
        end
        local part2 = ""
        if type(parts) == "table" and #parts >= 2 then
            part2 = string.lower(tostring(parts[2] or ""))
        end

        local actions = {
            apply = function()
                runtime.apply(true, "command")
            end,
            status = function()
                runtime.print_status()
            end,
            rebaseline = function()
                runtime.rebaseline()
            end,
            restore = function()
                runtime.restore()
            end,
            disable = function()
                runtime.disable()
            end,
        }

        local ui_actions = {
            get = ui_get,
            set = ui_set,
            apply = ui_apply,
            reload = ui_reload,
            save = ui_save,
            reset_core = ui_reset_core,
            status = ui_status,
        }

        local action = nil
        local action_name = nil
        local verb = nil
        local ui_verb = nil
        local ui_args = {}

        if cmd_lower == "tajsgraph.apply" or cmd_lower == "tajsgraph_apply" then
            verb = "apply"
        elseif cmd_lower == "tajsgraph.status" or cmd_lower == "tajsgraph_status" then
            verb = "status"
        elseif cmd_lower == "tajsgraph.rebaseline" or cmd_lower == "tajsgraph_rebaseline" then
            verb = "rebaseline"
        elseif cmd_lower == "tajsgraph.restore" or cmd_lower == "tajsgraph_restore" then
            verb = "restore"
        elseif cmd_lower == "tajsgraph.disable" or cmd_lower == "tajsgraph_disable" then
            verb = "disable"
        elseif cmd_lower == "tajsgraph.ui.get" or cmd_lower == "tajsgraph_ui_get" then
            ui_verb = "get"
            ui_args = slice_parts(parts, 1)
        elseif cmd_lower == "tajsgraph.ui.set" or cmd_lower == "tajsgraph_ui_set" then
            ui_verb = "set"
            ui_args = slice_parts(parts, 1)
        elseif cmd_lower == "tajsgraph.ui.apply" or cmd_lower == "tajsgraph_ui_apply" then
            ui_verb = "apply"
            ui_args = slice_parts(parts, 1)
        elseif cmd_lower == "tajsgraph.ui.reload" or cmd_lower == "tajsgraph_ui_reload" then
            ui_verb = "reload"
            ui_args = slice_parts(parts, 1)
        elseif cmd_lower == "tajsgraph.ui.save" or cmd_lower == "tajsgraph_ui_save" then
            ui_verb = "save"
            ui_args = slice_parts(parts, 1)
        elseif cmd_lower == "tajsgraph.ui.reset_core" or cmd_lower == "tajsgraph_ui_reset_core" then
            ui_verb = "reset_core"
            ui_args = slice_parts(parts, 1)
        elseif cmd_lower == "tajsgraph.ui.status" or cmd_lower == "tajsgraph_ui_status" then
            ui_verb = "status"
            ui_args = slice_parts(parts, 1)
        elseif cmd_lower == "tajsgraph.ui" then
            ui_verb = part1
            ui_args = slice_parts(parts, 2)
        elseif cmd_lower == "tajsgraph" then
            if part1 == "ui" then
                ui_verb = part2
                ui_args = slice_parts(parts, 3)
            else
                verb = part1
            end
        end

        if type(ui_verb) == "string" and ui_verb ~= "" then
            local ui_action = ui_actions[ui_verb]
            if type(ui_action) ~= "function" then
                log("ui command failed: unknown ui action '" .. tostring(ui_verb) .. "'")
                return true
            end

            local ok_run, run_err = ui_action(ui_args)
            if not ok_run then
                runtime.state.stats.last_error = tostring(run_err)
                log(string.format("ui.%s failed: %s", tostring(ui_verb), tostring(run_err)))
            end
            return true
        end

        if type(verb) == "string" and verb ~= "" then
            action = actions[verb]
            if type(action) == "function" then
                action_name = "tajsgraph." .. verb
            else
                action = nil
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
    register_command("tajsgraph.restore", command_wrapper)
    register_command("tajsgraph.disable", command_wrapper)
    register_command("tajsgraph_apply", command_wrapper)
    register_command("tajsgraph_status", command_wrapper)
    register_command("tajsgraph_rebaseline", command_wrapper)
    register_command("tajsgraph_restore", command_wrapper)
    register_command("tajsgraph_disable", command_wrapper)

    register_command("tajsgraph.ui", command_wrapper)
    register_command("tajsgraph.ui.get", command_wrapper)
    register_command("tajsgraph.ui.set", command_wrapper)
    register_command("tajsgraph.ui.apply", command_wrapper)
    register_command("tajsgraph.ui.reload", command_wrapper)
    register_command("tajsgraph.ui.save", command_wrapper)
    register_command("tajsgraph.ui.reset_core", command_wrapper)
    register_command("tajsgraph.ui.status", command_wrapper)
    register_command("tajsgraph_ui_get", command_wrapper)
    register_command("tajsgraph_ui_set", command_wrapper)
    register_command("tajsgraph_ui_apply", command_wrapper)
    register_command("tajsgraph_ui_reload", command_wrapper)
    register_command("tajsgraph_ui_save", command_wrapper)
    register_command("tajsgraph_ui_reset_core", command_wrapper)
    register_command("tajsgraph_ui_status", command_wrapper)

    SHARED.commands_registered = true

    log(string.format(
        "diag commands registered via %s: tajsgraph + tajsgraph.ui.* bridge",
        tostring(backend)
    ))
end

local function register_ui_hotkey()
    if SHARED.ui_hotkey_registered == true then
        return
    end

    if type(RegisterKeyBind) ~= "function" then
        log("diag ui hotkey unavailable")
        return
    end
    if type(Key) ~= "table" or type(ModifierKey) ~= "table" then
        log("diag ui hotkey unavailable (missing Key/ModifierKey table)")
        return
    end

    local key = Key.F9
    local modifiers = { ModifierKey.CONTROL, ModifierKey.SHIFT }
    if key == nil or modifiers[1] == nil or modifiers[2] == nil then
        log("diag ui hotkey unavailable (missing F9/CTRL/SHIFT constants)")
        return
    end

    if type(IsKeyBindRegistered) == "function" then
        local ok_check, already_registered = pcall(function()
            return IsKeyBindRegistered(key, modifiers)
        end)
        if ok_check and already_registered == true then
            log("diag ui hotkey not registered because Ctrl+Shift+F9 is already bound")
            return
        end
    end

    RegisterKeyBind(key, modifiers, function()
        log("ui hotkey pressed (Ctrl+Shift+F9): open UE4SS GUI Console and select tab 'TajsGraphBM UI'")
    end)
    SHARED.ui_hotkey_registered = true
    log("diag ui hotkey registered Ctrl+Shift+F9")
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

    ---@type fun(UClassName: string, Callback: function)|nil
    local notify_on_new_object = NotifyOnNewObject

    if type(notify_on_new_object) ~= "function" then
        log("NotifyOnNewObject unavailable; spawn listener disabled")
        return
    end

    log("diag hook NotifyOnNewObject SpotLightComponent active")
    notify_on_new_object("SpotLightComponent", function(...)
        local new_object = select(1, ...)
        safe_run("NotifyOnNewObject SpotLightComponent", function()
            runtime.on_spotlight_spawned(new_object)
        end)
    end)
end

register_commands()
register_ui_hotkey()
register_transition_hooks()
register_spawn_listener()
log("ui config path=" .. tostring(config_store_module.get_user_config_path()))
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
