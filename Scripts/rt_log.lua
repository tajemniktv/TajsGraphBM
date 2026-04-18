local M = {
    __tajsgraph_module = "rt_log"
}

local MOD_TAG = "[TajsGraphBM]"

function M.log(message)
    local line = string.format("%s %s", MOD_TAG, tostring(message))
    local line_with_newline = line .. "\n"
    if type(Log) == "function" then
        Log(line_with_newline)
        return
    end
    print(line_with_newline)
end

function M.safe_call(fn, ...)
    return pcall(fn, ...)
end

return M
