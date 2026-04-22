---Runtime compatibility shim for legacy requires.
---Delegates runtime creation to `rt_coordinator`.
local log_mod = require("rt_log")
local coordinator_module = require("rt_coordinator")

---@class TajsGraphRuntimeModule
local M = {
    __tajsgraph_module = "runtime"
}

---@param config table
---@return table
function M.new(config)
    return coordinator_module.new_runtime(config)
end

log_mod.log("runtime.lua shim active (delegating to rt_coordinator)")

return M
