-- ue4ss_runtime_stubs.lua
-- Stubs for UE4SS runtime-provided globals to satisfy the Lua language server diagnostics.

---@param offset number
---@return number
function DerefToInt32(offset) return 0 end

---@param offset number
---@return number
function DerefToInt64(offset) return 0 end

---@param offset number
---@return number
function DerefToFloat(offset) return 0.0 end

---@param name string
---@return any
function LoadExport(name) return nil end

-- common no-op helpers
function DerefToPointer(offset) return nil end

function DerefToUInt32(offset) return 0 end

return true
