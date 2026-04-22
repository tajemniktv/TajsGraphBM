local log_mod = require("rt_log")

---Scheduling helpers for delayed apply and backup loop behavior.
local M = {
    __tajsgraph_module = "rt_scheduler"
}

local safe_call = log_mod.safe_call

---Schedule a delayed apply using the best available UE4SS delay primitive.
---@param state table
---@param callback fun()
---@param delay_ms number
function M.schedule_apply(state, callback, delay_ms)
    if type(RetriggerableExecuteInGameThreadWithDelay) == "function" and type(MakeActionHandle) == "function" then
        if type(state.transition_apply_handle) ~= "number" then
            local ok_handle, handle = safe_call(function()
                return MakeActionHandle()
            end)
            if ok_handle and type(handle) == "number" then
                state.transition_apply_handle = handle
            end
        end

        if type(state.transition_apply_handle) == "number" then
            safe_call(function()
                RetriggerableExecuteInGameThreadWithDelay(state.transition_apply_handle, delay_ms, callback)
            end)
            return
        end
    end

    if type(ExecuteInGameThreadWithDelay) == "function" then
        safe_call(function()
            ExecuteInGameThreadWithDelay(delay_ms, callback)
        end)
        return
    end

    if type(ExecuteWithDelay) == "function" then
        safe_call(function()
            ExecuteWithDelay(delay_ms, callback)
        end)
        return
    end

    callback()
end

---Start the periodic backup loop once (idempotent per state generation).
---@param state table
---@param config table
---@param tick_fn fun()
function M.start_backup_loop(state, config, tick_fn)
    if state.loop_started then
        return
    end

    state.loop_started = true
    state.loop_generation = (state.loop_generation or 0) + 1
    local loop_generation = state.loop_generation
    local tick_ms = config.backup_tick_ms

    local function recurse()
        if not state.loop_started or state.loop_generation ~= loop_generation then
            return
        end

        tick_fn()

        if state.loop_started and type(ExecuteWithDelay) == "function" then
            safe_call(function()
                ExecuteWithDelay(tick_ms, recurse)
            end)
        end
    end

    if type(ExecuteWithDelay) == "function" then
        safe_call(function()
            ExecuteWithDelay(tick_ms, recurse)
        end)
    end
end

return M
