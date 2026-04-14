local log_mod = require("rt_log")
local state_mod = require("rt_state")
local stats_mod = require("rt_stats")
local spotlight_mod = require("rt_spotlight")
local render_mod = require("rt_render")
local scheduler_mod = require("rt_scheduler")

local M = {
    __tajsgraph_module = "rt_coordinator"
}

local log = log_mod.log
local safe_call = log_mod.safe_call

function M.new_runtime(config)
    local runtime = {}
    runtime.state = state_mod.new_state(config)
    runtime.config = config

    function runtime.apply(full_scan, reason)
        if runtime.state.in_progress then
            return false
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
        local should_log_success = reason == "startup" or reason == "startup_followup" or reason == "command" or reason == "rebaseline"
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
                    "diag apply reason=%s full_scan=%s render=%s force_refresh=%s found=%d->%d cached=%d->%d spot(a/c/f)=%d/%d/%d patch(last/total)=%d/%d",
                    tostring(reason),
                    tostring(do_full_scan),
                    tostring(do_render_pass),
                    tostring(force_refresh),
                    found_before, s.lights_found,
                    cached_before, s.lights_cached,
                    s.spot_attempted_last, s.spot_changed_last, s.spot_failed_last,
                    s.lights_patched_last, s.lights_patched_total
                ))
            end
        end

        if reason == "startup" and not runtime.state.warned_noop_tuning then
            if not spotlight_mod.is_tuning_effective(runtime.config) then
                runtime.state.warned_noop_tuning = true
                log("diag spotlight tuning currently has no visual delta (all multipliers are 1.0 or no absolute overrides)")
            end
        end

        return true
    end

    function runtime.schedule_apply(reason)
        if runtime.config.diagnostic_logging and reason ~= "backup_tick" then
            log("diag schedule reason=" .. tostring(reason))
        end
        scheduler_mod.schedule_apply(runtime.state, function()
            runtime.apply(true, reason)
        end, runtime.config.transition_apply_delay_ms)
    end

    function runtime.start_backup_loop()
        scheduler_mod.start_backup_loop(runtime.state, runtime.config, function()
            runtime.apply(false, "backup_tick")
        end)
    end

    function runtime.on_spotlight_spawned(light)
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

    function runtime.rebaseline()
        local updated = spotlight_mod.rebaseline_spotlights(runtime.state)
        log(string.format("rebaseline updated=%d", updated))
        runtime.apply(false, "rebaseline")
    end

    function runtime.status_line()
        local s = runtime.state.stats
        return string.format(
            "status runs=%d found=%d cached=%d lights_patched(last/total)=%d/%d spot(last a/c/f)=%d/%d/%d spot(total a/c/f)=%d/%d/%d megalights(last a/s/f)=%d/%d/%d lumen(last a/s/f)=%d/%d/%d",
            s.apply_runs,
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
            s.megalights_attempts_last,
            s.megalights_success_last,
            s.megalights_fail_last,
            s.lumen_attempts_last,
            s.lumen_success_last,
            s.lumen_fail_last
        )
    end

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
