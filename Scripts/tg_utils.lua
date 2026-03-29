local M = {}

local MOD_TAG = "[TajsGraphBM]"

local function log(msg)
	print(string.format("%s %s\n", MOD_TAG, msg))
end

local function is_valid(obj)
	if obj == nil then
		return false
	end

	local has_is_valid_ok, has_is_valid = pcall(function()
		return obj.IsValid ~= nil
	end)
	if not has_is_valid_ok or not has_is_valid then
		return false
	end

	local ok, result = pcall(function()
		return obj:IsValid()
	end)

	return ok and result == true
end

local function get_field(obj, field_name)
	if not is_valid(obj) then
		return false, nil
	end

	local ok, value = pcall(function()
		return obj[field_name]
	end)

	if ok then
		return true, value
	end

	return false, nil
end

local function get_object_property(obj, field_name)
	local ok, value = get_field(obj, field_name)
	if ok then
		return value
	end
	return nil
end

local function set_field(obj, field_name, value)
	if not is_valid(obj) then
		return false
	end

	local ok = pcall(function()
		obj[field_name] = value
	end)

	return ok
end

local function call_method_if_valid(obj, method_name, ...)
	if not is_valid(obj) then
		return false
	end

	local args = { ... }
	local ok_call = pcall(function()
		local method = obj[method_name]
		return method(obj, table.unpack(args))
	end)
	if not ok_call then
		return false
	end

	return true
end

local function set_numeric_property(obj, field_name, value, setter_name)
	if type(value) ~= "number" then
		return false
	end

	local ok_field = set_field(obj, field_name, value)
	if ok_field then
		return true
	end

	if type(setter_name) == "string" and setter_name ~= "" then
		return call_method_if_valid(obj, setter_name, value)
	end

	return false
end

local function set_bool_property_confirmed(obj, field_name, enabled)
	if type(enabled) ~= "boolean" then
		return false
	end

	if not set_field(obj, field_name, enabled) then
		return false
	end

	local ok, current = get_field(obj, field_name)
	return ok and current == enabled
end

local function set_number_property_confirmed(obj, field_name, value, setter_name)
	if type(value) ~= "number" then
		return false
	end

	local wrote = set_numeric_property(obj, field_name, value, setter_name)
	if not wrote then
		return false
	end

	local ok, current = get_field(obj, field_name)
	return ok and type(current) == "number" and math.abs(current - value) <= 0.0001
end

local function set_bool_property_multi(obj, field_names, enabled, setter_name)
	if type(enabled) ~= "boolean" then
		return false
	end

	if type(setter_name) == "string" and setter_name ~= "" and call_method_if_valid(obj, setter_name, enabled) then
		if type(field_names) == "table" then
			for _, field_name in ipairs(field_names) do
				if type(field_name) == "string" and field_name ~= "" then
					local ok, current = get_field(obj, field_name)
					if ok and current == enabled then
						return true
					end
				end
			end
		end

		return true
	end

	if type(field_names) ~= "table" then
		return false
	end

	for _, field_name in ipairs(field_names) do
		if type(field_name) == "string" and field_name ~= "" and set_bool_property_confirmed(obj, field_name, enabled) then
			return true
		end
	end

	return false
end

local function safe_inc_reason(map, key)
	if type(key) ~= "string" or key == "" then
		return
	end
	map[key] = (map[key] or 0) + 1
end

local function get_time_ms()
	return math.floor(os.clock() * 1000)
end

local function get_objects_of_class(class_name)
	if type(FindAllOf) ~= "function" then
		return {}
	end

	local ok, objects = pcall(FindAllOf, class_name)
	if ok and type(objects) == "table" then
		return objects
	end

	return {}
end

M.log = log
M.is_valid = is_valid
M.get_field = get_field
M.get_object_property = get_object_property
M.set_field = set_field
M.call_method_if_valid = call_method_if_valid
M.set_numeric_property = set_numeric_property
M.set_bool_property_confirmed = set_bool_property_confirmed
M.set_number_property_confirmed = set_number_property_confirmed
M.set_bool_property_multi = set_bool_property_multi
M.safe_inc_reason = safe_inc_reason
M.get_time_ms = get_time_ms
M.get_objects_of_class = get_objects_of_class

return M
