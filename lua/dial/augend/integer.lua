local common = require"dial.augend.common"
local util   = require "dial.util"

-- ---@alias AugendIntegerConfig { radix?: integer, prefix?: string, natural?: boolean, case?: '"upper"' | '"lower"' }
---@alias AugendIntegerConfig {}

---@class AugendInteger
---@implement Augend
---@field radix integer
---@field prefix string
---@field natural boolean
---@field query string
---@field case '"upper"' | '"lower"'
local AugendInteger = {}

local M = {}

---convert integer with given prefix
---@param n integer
---@param radix integer
---@param case '"upper"' | '"lower"'
---@return string
local function tostring_with_radix(n, radix, case)
    local floor,insert = math.floor, table.insert
    n = floor(n)
    if not radix or radix == 10 then return tostring(n) end

    local digits = "0123456789abcdefghijklmnopqrstuvwxyz"
    if case == "upper" then
        digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    end

    local t = {}
    local sign = ""
    if n < 0 then
        sign = "-"
    n = -n
    end
    repeat
        local d = (n % radix) + 1
        n = floor(n / radix)
        insert(t, 1, digits:sub(d,d))
    until n == 0
    return sign .. table.concat(t,"")
end

---@param radix integer
---@return string
local function radix_to_query_character(radix)
    if radix < 2 or radix > 36 then
        error(("radix must satisfy 2 <= radix <= 36, got %d"):format(radix))
    end
    if radix <= 10 then
        return "0-" .. tostring(radix - 1)
    end
    return "0-9a-" .. string.char(86 + radix) .. "A-" .. string.char(54 + radix)
end

---@param config AugendIntegerConfig
---@return Augend
function M.new(config)
    vim.validate{
        radix = {config.radix, "number", true},
        prefix = {config.prefix, "string", true},
        natural = {config.natural, "boolean", true},
        case = {config.case, "string", true},
    }
    local radix = util.unwrap_or(config.radix, 10)
    local prefix = util.unwrap_or(config.prefix, "")
    local natural = util.unwrap_or(config.natural, true)
    local case = util.unwrap_or(config.case, "lower")
    local query = prefix .. util.if_expr(natural, "", "-?") .. "[" .. radix_to_query_character(radix) .. "]+"

    return setmetatable({radix = radix, prefix = prefix, natural = natural, query = query, case = case}, {__index = AugendInteger})
end

---@param line string
---@param cursor? integer
---@return textrange?
function AugendInteger:find(line, cursor)
    return common.find_pattern(self.query)(line, cursor)
end

---@param text string
---@param addend integer
---@param cursor? integer
---@return { text?: string, cursor?: integer }
function AugendInteger:add(text, addend, cursor)
    local n_prefix = #self.prefix
    local subtext = text:sub(n_prefix + 1)
    local n = tonumber(subtext, self.radix)
    local n_string_digit = subtext:len()
    -- local n_actual_digit = tostring(n):len()
    local n_actual_digit = tostring_with_radix(n, self.radix, self.case):len()
    n = n + addend
    util.dbg{text = text, n = n, query = self.query}
    if self.natural and n < 0 then
        n = 0
    end
    local digits
    if n_string_digit == n_actual_digit then
        -- 増減前の数字が0か0始まりでない数字だったら
        -- text = ("%d"):format(n)
        digits = tostring_with_radix(n, self.radix, self.case)
    else
        -- 増減前の数字が0始まりの正の数だったら
        -- text = ("%0" .. n_string_digit .. "d"):format(n)
        local num_string = tostring_with_radix(n, self.radix, self.case)
        local pad = ("0"):rep(math.max(n_string_digit - num_string:len(), 0))
        digits = pad .. num_string
    end
    text = self.prefix .. digits
    cursor = #text
    return {text = text, cursor = cursor}
end

return M
