local log_mod = require("rt_log")
local state_mod = require("rt_state")
local stats_mod = require("rt_stats")
local spotlight_mod = require("rt_spotlight")
local render_mod = require("rt_render")
local scheduler_mod = require("rt_scheduler")

---Coordinator that orchestrates spotlight, render, scheduling and restore flows.
local M = {
    __tajsgraph_module = "rt_coordinator"
}

local log = log_mod.log
local safe_call = log_mod.safe_call

---@param command string
---@return boolean
local function run_console_command(command)
    if type(command) ~= "string" or command == "" then
        return false
    end

    local function try_process_console_exec(target, executor)
        if target == nil or type(target.ProcessConsoleExec) ~= "function" then
            return false
        end

        local ok = safe_call(function()
            target:ProcessConsoleExec(command, nil, executor or target)
        end)
        return ok
    end

    local ok_viewport, viewport = safe_call(function()
        if type(FindFirstOf) == "function" then
            return FindFirstOf("GameViewportClient")
        end
        return nil
    end)
    if ok_viewport and viewport ~= nil then
        if try_process_console_exec(viewport, viewport) then
            return true
        end
    end

    local ok_pc, pc = safe_call(function()
        if type(FindFirstOf) == "function" then
            return FindFirstOf("PlayerController")
        end
        return nil
    end)
    if ok_pc and pc ~= nil then
        local ok_console_call, console_call_result = safe_call(function()
            if type(pc.ConsoleCommand) == "function" then
                pc:ConsoleCommand(command)
                return true
            end
            return false
        end)
        if ok_console_call and console_call_result == true then
            return true
        end

        if try_process_console_exec(pc, pc) then
            return true
        end
    end

    return false
end

---@param delay_ms number
---@param callback fun()
---@return boolean
local function schedule_delay(delay_ms, callback)
    if type(callback) ~= "function" then
        return false
    end

    if type(ExecuteInGameThreadWithDelay) == "function" then
        local ok = safe_call(function()
            ExecuteInGameThreadWithDelay(delay_ms, callback)
        end)
        if ok then
            return true
        end
    end

    if type(ExecuteWithDelay) == "function" then
        local ok = safe_call(function()
            ExecuteWithDelay(delay_ms, callback)
        end)
        if ok then
            return true
        end
    end

    if type(ExecuteInGameThread) == "function" then
        local ok = safe_call(function()
            ExecuteInGameThread(callback)
        end)
        if ok then
            return true
        end
    end

    local ok = safe_call(callback)
    return ok
end

---@param config table
---@param reason string
---@return boolean
local function should_run_post_apply_vsm_pulse(config, reason)
    if config.post_apply_vsm_reload_enabled ~= true then
        return false
    end

    if reason == "command" then
        return true
    end

    if reason == "rebaseline" and config.post_apply_vsm_reload_on_rebaseline == true then
        return true
    end

    return false
end

---@param runtime table
---@param reason string
local function run_post_apply_vsm_pulse(runtime, reason)
    local config = runtime.config
    local off_value = math.floor(tonumber(config.post_apply_vsm_reload_off_value) or 0)
    local on_value = math.floor(tonumber(config.post_apply_vsm_reload_on_value) or 1)
    local delay_ms = math.max(0, math.floor(tonumber(config.post_apply_vsm_reload_delay_ms) or 0))

    local cvar_name = "r.shadow.virtual.enable"
    local off_cmd = string.format("%s %d", cvar_name, off_value)
    local on_cmd = string.format("%s %d", cvar_name, on_value)

    local off_ok = run_console_command(off_cmd)
    if not off_ok then
        log(string.format("diag post-apply VSM pulse failed to run '%s'", off_cmd))
        return
    end

    local scheduled = schedule_delay(delay_ms, function()
        local on_ok = run_console_command(on_cmd)
        if not on_ok then
            log(string.format("diag post-apply VSM pulse failed to run '%s'", on_cmd))
        end
    end)

    if config.diagnostic_logging then
        log(string.format(
            "diag post-apply VSM pulse reason=%s off=%d on=%d delay_ms=%d scheduled=%s",
            tostring(reason),
            off_value,
            on_value,
            delay_ms,
            tostring(scheduled)
        ))
    end
end

---Create a runtime instance bound to one normalized config table.
---@param config table
---@return table
function M.new_runtime(config)
    local runtime = {}
    runtime.state = state_mod.new_state(config)
    runtime.config = config

    ---@return table
    function runtime.get_config()
        return runtime.config
    end

    ---@param new_config table
    ---@return boolean, string|nil
    function runtime.set_config(new_config)
        if type(new_config) ~= "table" then
            return false, "new_config must be table"
        end
        runtime.config = new_config
        runtime.state.config = new_config
        return true, nil
    end

    ---@param reason string
    ---@return boolean
    local function should_skip_apply_when_disabled(reason)
        return runtime.state.disabled == true and reason ~= "command"
    end

    ---@param message string
    ---@param key string|nil
    local function detail_restore_log(message, key)
        if runtime.config.diagnostic_logging ~= true then
            return
        end
        if type(key) == "string" and key ~= "" then
            log(string.format("restore %s key=%s", tostring(message), tostring(key)))
            return
        end
        log("restore " .. tostring(message))
    end

    ---@param reason string
    ---@return boolean
    local function perform_restore(reason)
        local s = runtime.state.stats
        s.restore_runs = s.restore_runs + 1

        s.restore_spotlights_attempted_last = 0
        s.restore_spotlights_restored_last = 0
        s.restore_spotlights_skipped_last = 0
        s.restore_spotlights_failed_last = 0
        s.restore_properties_restored_last = 0
        s.restore_properties_skipped_last = 0
        s.restore_properties_failed_last = 0
        s.restore_render_restored_last = 0
        s.restore_render_failed_last = 0

        local spot_summary = spotlight_mod.restore_spotlights(runtime.state, detail_restore_log)
        local render_summary = render_mod.restore_render_compat(runtime.state, runtime.config)

        local state_ctx = string.format(
            "disabled=%s in_progress=%s apply_cycle=%s",
            tostring(runtime.state.disabled),
            tostring(runtime.state.in_progress),
            tostring(runtime.state.apply_cycle)
        )

        if type(spot_summary) ~= "table" then
            log(string.format(
                "restore spotlight summary missing (reason=%s %s); using safe defaults",
                tostring(reason),
                state_ctx
            ))
            detail_restore_log("spotlight restore summary missing; using safe defaults", "summary")
            spot_summary = {
                attempted = 0,
                restored = 0,
                skipped = 0,
                failed = 0,
                properties_restored = 0,
                properties_skipped = 0,
                properties_failed = 0,
            }
        end

        if type(render_summary) ~= "table" then
            log(string.format(
                "restore render summary missing (reason=%s %s); using safe defaults",
                tostring(reason),
                state_ctx
            ))
            render_summary = {
                restored = 0,
                failed = 0,
            }
        end

        s.restore_spotlights_attempted_last = spot_summary.attempted
        s.restore_spotlights_attempted_total = s.restore_spotlights_attempted_total + spot_summary.attempted
        s.restore_spotlights_restored_last = spot_summary.restored
        s.restore_spotlights_restored_total = s.restore_spotlights_restored_total + spot_summary.restored
        s.restore_spotlights_skipped_last = spot_summary.skipped
        s.restore_spotlights_skipped_total = s.restore_spotlights_skipped_total + spot_summary.skipped
        s.restore_spotlights_failed_last = spot_summary.failed
        s.restore_spotlights_failed_total = s.restore_spotlights_failed_total + spot_summary.failed

        s.restore_properties_restored_last = spot_summary.properties_restored
        s.restore_properties_restored_total = s.restore_properties_restored_total + spot_summary.properties_restored
        s.restore_properties_skipped_last = spot_summary.properties_skipped
        s.restore_properties_skipped_total = s.restore_properties_skipped_total + spot_summary.properties_skipped
        s.restore_properties_failed_last = spot_summary.properties_failed
        s.restore_properties_failed_total = s.restore_properties_failed_total + spot_summary.properties_failed

        s.restore_render_restored_last = render_summary.restored
        s.restore_render_restored_total = s.restore_render_restored_total + render_summary.restored
        s.restore_render_failed_last = render_summary.failed
        s.restore_render_failed_total = s.restore_render_failed_total + render_summary.failed

        log(string.format(
            "restore ok reason=%s spotlights(a/r/s/f)=%d/%d/%d/%d props(r/s/f)=%d/%d/%d render(r/f)=%d/%d",
            tostring(reason),
            spot_summary.attempted,
            spot_summary.restored,
            spot_summary.skipped,
            spot_summary.failed,
            spot_summary.properties_restored,
            spot_summary.properties_skipped,
            spot_summary.properties_failed,
            render_summary.restored,
            render_summary.failed
        ))

        return true
    end

    ---Apply spotlight/render changes for this runtime.
    ---@param full_scan boolean
    ---@param reason string
    ---@return boolean
    function runtime.apply(full_scan, reason)
        if runtime.state.in_progress then
            return false
        end

        if should_skip_apply_when_disabled(reason) then
            return true
        end

        if runtime.state.disabled == true and reason == "command" then
            runtime.state.disabled = false
            log("apply command re-enabled runtime")
        end

        local do_full_scan = full_scan == true
        local do_render_pass = true
        local force_refresh = (reason == "command" or reason == "rebaseline")

        if reason == "backup_tick" then
            runtime.state.backup_tick_counter = runtime.state.backup_tick_counter + 1
            if runtime.state.backup_tick_counter % runtime.config.backup_full_scan_every_ticks == 0 then
                do_full_scan = true
            end
            do_render_pass = (runtime.state.backup_tick_counter % runtime.config.backup_render_every_ticks == 0)
            runtime.state.backup_diag_counter = runtime.state.backup_diag_counter + 1
        else
            runtime.state.backup_tick_counter = 0
            runtime.state.backup_diag_counter = 0
        end

        runtime.state.in_progress = true
        runtime.state.stats.apply_runs = runtime.state.stats.apply_runs + 1
        runtime.state.apply_cycle = runtime.state.apply_cycle + 1
        runtime.state.stats.last_error = ""
        local found_before = runtime.state.stats.lights_found
        local cached_before = runtime.state.stats.lights_cached
        stats_mod.reset_last_counters(runtime.state)

        local ok, err = safe_call(function()
            if do_full_scan then
                spotlight_mod.discover_spotlights(runtime.state)
            end
            spotlight_mod.apply_spotlights(runtime.state, runtime.config, force_refresh)
            if do_render_pass then
                render_mod.apply_render_compat(runtime.state, runtime.config)
            end
            spotlight_mod.prune_spotlight_cache(runtime.state)
        end)

        runtime.state.in_progress = false

        if not ok then
            runtime.state.stats.last_error = tostring(err)
            log("apply failed: " .. runtime.state.stats.last_error)
            return false
        end

        -- Keep normal diagnostics concise; avoid log spam from frequent background applies.
        local should_log_success = reason == "startup" or reason == "startup_followup" or reason == "command" or
            reason == "rebaseline"
        if should_log_success and reason ~= nil and reason ~= "" then
            log("apply ok reason=" .. tostring(reason))
        end

        if runtime.config.diagnostic_logging then
            local emit_backup_diag = reason == "backup_tick" and (
                do_full_scan or runtime.state.backup_diag_counter % runtime.config.backup_diagnostic_every_ticks == 0
            )
            local emit_regular_diag = reason ~= "backup_tick"
            if emit_regular_diag or emit_backup_diag then
                local s = runtime.state.stats
                log(string.format(
                    "diag apply reason=%s full_scan=%s render=%s force_refresh=%s found=%d->%d cached=%d->%d spot(a/c/f)=%d/%d/%d mobility_fail=%d patch(last/total)=%d/%d",
                    tostring(reason),
                    tostring(do_full_scan),
                    tostring(do_render_pass),
                    tostring(force_refresh),
                    found_before, s.lights_found,
                    cached_before, s.lights_cached,
                    s.spot_attempted_last, s.spot_changed_last, s.spot_failed_last,
                    s.mobility_fail_last,
                    s.lights_patched_last, s.lights_patched_total
                ))
            end
        end

        if reason == "command" then
            local s = runtime.state.stats
            if s.spot_attempted_last > 0 and s.spot_changed_last == 0 then
                log(
                    "diag command apply produced zero spotlight numeric changes; verify config multipliers/absolute values")
            end
        end

        if reason == "startup" and not runtime.state.warned_noop_tuning then
            if not spotlight_mod.is_tuning_effective(runtime.config) then
                runtime.state.warned_noop_tuning = true
                log(
                    "diag spotlight tuning currently has no visual delta (all multipliers are 1.0 or no absolute overrides)")
            end
        end

        if should_run_post_apply_vsm_pulse(runtime.config, reason) then
            run_post_apply_vsm_pulse(runtime, reason)
        end

        return true
    end

    ---Schedule a delayed full apply for transition/spawn recovery paths.
    ---@param reason string
    function runtime.schedule_apply(reason)
        if should_skip_apply_when_disabled(reason) then
            return
        end

        if runtime.config.diagnostic_logging and reason ~= "backup_tick" then
            log("diag schedule reason=" .. tostring(reason))
        end
        scheduler_mod.schedule_apply(runtime.state, function()
            runtime.apply(true, reason)
        end, runtime.config.transition_apply_delay_ms)
    end

    ---Start the periodic backup loop (idempotent).
    function runtime.start_backup_loop()
        scheduler_mod.start_backup_loop(runtime.state, runtime.config, function()
            runtime.apply(false, "backup_tick")
        end)
    end

    ---Fast path for newly spawned spotlights discovered via NotifyOnNewObject.
    ---@param light any
    function runtime.on_spotlight_spawned(light)
        if runtime.state.disabled == true then
            return
        end

        local ok, err = safe_call(function()
            runtime.state.apply_cycle = runtime.state.apply_cycle + 1
            stats_mod.reset_last_counters(runtime.state)

            local patched = spotlight_mod.apply_spawned_spotlight(runtime.state, runtime.config, light)
            if not patched then
                runtime.schedule_apply("spawn_recover")
            elseif runtime.config.diagnostic_logging then
                runtime.state.spawn_patch_count = runtime.state.spawn_patch_count + 1
                if runtime.state.spawn_patch_count <= 5 or runtime.state.spawn_patch_count % runtime.state.spawn_log_batch == 0 then
                    local light_key = tostring(light)
                    local ok_name, full_name = safe_call(function()
                        if light ~= nil and type(light.GetFullName) == "function" then
                            return light:GetFullName()
                        end
                        return nil
                    end)
                    if ok_name and type(full_name) == "string" and full_name ~= "" then
                        light_key = full_name
                    end
                    log(string.format("diag spawn patched count=%d key=%s", runtime.state.spawn_patch_count, light_key))
                end
            end
        end)

        if not ok then
            runtime.state.stats.last_error = tostring(err)
            log("spawn patch failed: " .. runtime.state.stats.last_error)
        end
    end

    ---Rebuild baselines from current spotlight values, then re-apply once.
    function runtime.rebaseline()
        local updated = spotlight_mod.rebaseline_spotlights(runtime.state)
        log(string.format("rebaseline updated=%d", updated))
        runtime.apply(false, "rebaseline")
    end

    ---Restore captured values and disable runtime auto-application.
    ---@return boolean
    function runtime.restore()
        local ok, err = safe_call(function()
            perform_restore("command_restore")
        end)

        if not ok then
            runtime.state.stats.last_error = tostring(err)
            log("restore failed: " .. runtime.state.stats.last_error)
            return false
        end

        runtime.state.disabled = true
        log("restore complete; runtime is disabled until explicit apply")
        return true
    end

    ---Restore captured values and disable runtime auto-application.
    ---@return boolean
    function runtime.disable()
        runtime.state.stats.disable_runs = runtime.state.stats.disable_runs + 1

        local ok, err = safe_call(function()
            perform_restore("command_disable")
        end)

        if not ok then
            runtime.state.stats.last_error = tostring(err)
            log("disable failed: " .. runtime.state.stats.last_error)
            return false
        end

        runtime.state.disabled = true
        log("disable complete; runtime auto-apply is suspended")
        return true
    end

    ---@return string
    function runtime.status_line()
        local s = runtime.state.stats
        return string.format(
            "status disabled=%s runs=%d disable_runs=%d restore_runs=%d found=%d cached=%d lights_patched(last/total)=%d/%d spot(last a/c/f)=%d/%d/%d spot(total a/c/f)=%d/%d/%d mobility_fail(last/total)=%d/%d restore_spot(a/r/s/f last)=%d/%d/%d/%d restore_props(r/s/f last)=%d/%d/%d render_restore(r/f last)=%d/%d megalights(last a/s/f)=%d/%d/%d lumen(last a/s/f)=%d/%d/%d",
            tostring(runtime.state.disabled),
            s.apply_runs,
            s.disable_runs,
            s.restore_runs,
            s.lights_found,
            s.lights_cached,
            s.lights_patched_last,
            s.lights_patched_total,
            s.spot_attempted_last,
            s.spot_changed_last,
            s.spot_failed_last,
            s.spot_attempted_total,
            s.spot_changed_total,
            s.spot_failed_total,
            s.mobility_fail_last,
            s.mobility_fail_total,
            s.restore_spotlights_attempted_last,
            s.restore_spotlights_restored_last,
            s.restore_spotlights_skipped_last,
            s.restore_spotlights_failed_last,
            s.restore_properties_restored_last,
            s.restore_properties_skipped_last,
            s.restore_properties_failed_last,
            s.restore_render_restored_last,
            s.restore_render_failed_last,
            s.megalights_attempts_last,
            s.megalights_success_last,
            s.megalights_fail_last,
            s.lumen_attempts_last,
            s.lumen_success_last,
            s.lumen_fail_last
        )
    end

    ---Emit status and last_error lines to log output.
    function runtime.print_status()
        log(runtime.status_line())
        local err = runtime.state.stats.last_error
        if type(err) == "string" and err ~= "" then
            log("status last_error=" .. err)
        end
    end

    return runtime
end

return M
