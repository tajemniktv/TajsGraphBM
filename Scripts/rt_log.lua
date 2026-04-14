local M = {
    __tajsgraph_module = "rt_log"
}

local MOD_TAG = "[TajsGraphBM]"

function M.log(message)
    print(string.format("%s %s", MOD_TAG, tostring(message)))
end

function M.safe_call(fn, ...)
    return pcall(fn, ...)
end

return M
