---Shared logging and protected-call helpers.
local M = {
    __tajsgraph_module = "rt_log"
}

local MOD_TAG = "[TajsGraphBM]"

---@param message any
function M.log(message)
    local line = string.format("%s %s", MOD_TAG, tostring(message))
    local line_with_newline = line .. "\n"
    if type(Log) == "function" then
        Log(line_with_newline)
        return
    end
    print(line_with_newline)
end

---Wrapper around `pcall` for consistent import pattern across runtime modules.
---@generic T
---@param fn fun(...):T
---@param ... any
---@return boolean, T|any
function M.safe_call(fn, ...)
    return pcall(fn, ...)
end

return M
