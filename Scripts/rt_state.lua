local stats_mod = require("rt_stats")

---Runtime state factory for coordinator instances.
local M = {
    __tajsgraph_module = "rt_state"
}

---Create a fresh mutable runtime state bucket.
---@param config table
---@return table
function M.new_state(config)
    return {
        config = config,
        in_progress = false,
        disabled = false,
        apply_cycle = 0,
        loop_started = false,
        backup_tick_counter = 0,
        backup_diag_counter = 0,
        loop_generation = 0,
        warned_noop_tuning = false,
        warned_no_render_targets = false,
        spawn_patch_count = 0,
        spawn_log_batch = 25,
        light_entries = {},
        render_original = {},
        stats = stats_mod.new_stats(),
        backup_loop_handle = nil,
        transition_apply_handle = nil,
    }
end

return M
