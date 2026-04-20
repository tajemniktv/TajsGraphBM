local log_mod = require("rt_log")

local M = {
    __tajsgraph_module = "rt_stats"
}

local safe_call = log_mod.safe_call

function M.new_stats()
    return {
        apply_runs = 0,
        last_error = "",

        lights_found = 0,
        lights_cached = 0,
        lights_patched_last = 0,
        lights_patched_total = 0,

        spot_attempted_last = 0,
        spot_attempted_total = 0,
        spot_changed_last = 0,
        spot_changed_total = 0,
        spot_failed_last = 0,
        spot_failed_total = 0,
        mobility_fail_last = 0,
        mobility_fail_total = 0,

        megalights_attempts_last = 0,
        megalights_attempts_total = 0,
        megalights_success_last = 0,
        megalights_success_total = 0,
        megalights_fail_last = 0,
        megalights_fail_total = 0,

        lumen_attempts_last = 0,
        lumen_attempts_total = 0,
        lumen_success_last = 0,
        lumen_success_total = 0,
        lumen_fail_last = 0,
        lumen_fail_total = 0,

        disable_runs = 0,
        restore_runs = 0,
        restore_spotlights_attempted_last = 0,
        restore_spotlights_attempted_total = 0,
        restore_spotlights_restored_last = 0,
        restore_spotlights_restored_total = 0,
        restore_spotlights_skipped_last = 0,
        restore_spotlights_skipped_total = 0,
        restore_spotlights_failed_last = 0,
        restore_spotlights_failed_total = 0,
        restore_properties_restored_last = 0,
        restore_properties_restored_total = 0,
        restore_properties_skipped_last = 0,
        restore_properties_skipped_total = 0,
        restore_properties_failed_last = 0,
        restore_properties_failed_total = 0,
        restore_render_restored_last = 0,
        restore_render_restored_total = 0,
        restore_render_failed_last = 0,
        restore_render_failed_total = 0,
    }
end

function M.reset_last_counters(state)
    local s = state.stats
    s.lights_patched_last = 0

    s.spot_attempted_last = 0
    s.spot_changed_last = 0
    s.spot_failed_last = 0
    s.mobility_fail_last = 0

    s.megalights_attempts_last = 0
    s.megalights_success_last = 0
    s.megalights_fail_last = 0

    s.lumen_attempts_last = 0
    s.lumen_success_last = 0
    s.lumen_fail_last = 0
end

function M.count_operation(state, bucket, success)
    local s = state.stats
    if bucket == "megalights" then
        s.megalights_attempts_last = s.megalights_attempts_last + 1
        s.megalights_attempts_total = s.megalights_attempts_total + 1
        if success then
            s.megalights_success_last = s.megalights_success_last + 1
            s.megalights_success_total = s.megalights_success_total + 1
        else
            s.megalights_fail_last = s.megalights_fail_last + 1
            s.megalights_fail_total = s.megalights_fail_total + 1
        end
        return
    end

    s.lumen_attempts_last = s.lumen_attempts_last + 1
    s.lumen_attempts_total = s.lumen_attempts_total + 1
    if success then
        s.lumen_success_last = s.lumen_success_last + 1
        s.lumen_success_total = s.lumen_success_total + 1
    else
        s.lumen_fail_last = s.lumen_fail_last + 1
        s.lumen_fail_total = s.lumen_fail_total + 1
    end
end

function M.safe_set_last_error(state, err)
    local ok = safe_call(function()
        state.stats.last_error = tostring(err)
    end)
    return ok
end

return M
