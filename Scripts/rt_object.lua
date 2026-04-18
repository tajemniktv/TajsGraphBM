local log_mod = require("rt_log")

local M = {
    __tajsgraph_module = "rt_object"
}

local safe_call = log_mod.safe_call

function M.is_valid_object(obj)
    if obj == nil then
        return false
    end

    local ok, result = safe_call(function()
        if type(obj.IsValid) == "function" then
            return obj:IsValid()
        end
        return true
    end)

    return ok and result == true
end

function M.safe_get(obj, field)
    local ok, value = safe_call(function()
        return obj[field]
    end)
    if not ok then
        return false, nil
    end
    return true, value
end

function M.safe_set(obj, field, value)
    return safe_call(function()
        obj[field] = value
    end)
end

function M.read_numeric_property(obj, field)
    local ok, value = M.safe_get(obj, field)
    if not ok or type(value) ~= "number" then
        return false, nil
    end
    return true, value
end

function M.read_bool_property(obj, field)
    local ok, value = M.safe_get(obj, field)
    if not ok or type(value) ~= "boolean" then
        return false, nil
    end
    return true, value
end

local function parse_mobility_value(value)
    if type(value) == "number" then
        return math.floor(value)
    end

    local as_string = tostring(value or "")
    local lower = string.lower(as_string)
    if lower:find("movable", 1, true) then
        return 2
    end
    if lower:find("stationary", 1, true) then
        return 1
    end
    if lower:find("static", 1, true) then
        return 0
    end

    local numeric_match = lower:match("(%d+)")
    if numeric_match ~= nil then
        return math.floor(tonumber(numeric_match) or 0)
    end

    return nil
end

function M.read_mobility_property(obj)
    local ok_mobility, mobility = M.safe_get(obj, "Mobility")
    if ok_mobility then
        local parsed = parse_mobility_value(mobility)
        if parsed ~= nil then
            return true, parsed
        end
    end

    local ok_private, mobility_private = M.safe_get(obj, "MobilityPrivate")
    if ok_private then
        local parsed_private = parse_mobility_value(mobility_private)
        if parsed_private ~= nil then
            return true, parsed_private
        end
    end

    return false, nil
end

function M.object_key(obj)
    local full_name = nil

    if M.is_valid_object(obj) then
        local ok_get_full_name, value = safe_call(function()
            if type(obj.GetFullName) == "function" then
                return obj:GetFullName()
            end
            return nil
        end)

        if ok_get_full_name and type(value) == "string" and value ~= "" then
            full_name = value
        end
    end

    if full_name == nil then
        local ok_to_string, value = safe_call(function()
            return tostring(obj)
        end)
        full_name = ok_to_string and tostring(value) or "unknown"
    end

    return full_name
end

function M.guarded_write(obj, field, value, on_operation, bucket)
    if not M.is_valid_object(obj) then
        if type(on_operation) == "function" then
            on_operation(bucket, false)
        end
        return false
    end

    local ok_read = safe_call(function()
        local _ = obj[field]
        return _
    end)

    if not ok_read then
        if type(on_operation) == "function" then
            on_operation(bucket, false)
        end
        return false
    end

    local ok_write = M.safe_set(obj, field, value)
    if type(on_operation) == "function" then
        on_operation(bucket, ok_write)
    end
    return ok_write
end

function M.call_method_if_valid(obj, method_name, ...)
    if not M.is_valid_object(obj) then
        return false
    end

    local ok, method = M.safe_get(obj, method_name)
    if not ok or type(method) ~= "function" then
        return false
    end

    local args = { ... }
    local argc = select("#", ...)
    local ok_call = safe_call(function()
        method(obj, table.unpack(args, 1, argc))
    end)
    return ok_call
end

function M.set_number_with_setter(obj, field, value, setter_name)
    local set_ok = false
    if type(setter_name) == "string" and setter_name ~= "" then
        set_ok = M.call_method_if_valid(obj, setter_name, value)
    end

    if set_ok then
        return true
    end

    return M.safe_set(obj, field, value)
end

return M
