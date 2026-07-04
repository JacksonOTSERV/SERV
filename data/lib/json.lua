
-- Module: dkjson
-- Version: 2.5
-- Authors: David Heiko Kolf
-- License: MIT (see end of file)

local always_try_using_lpeg = true
local register_global_module_table = false
local global_module_name = 'json'

local M = {}

local _G = _G
local tostring = tostring
local tonumber = tonumber
local type = type
local pairs = pairs
local ipairs = ipairs
local next = next
local string = string
local math = math
local table = table
local error = error
local getmetatable = getmetatable
local setmetatable = setmetatable

local str_find = string.find
local str_match = string.match
local str_sub = string.sub
local str_gsub = string.gsub
local str_len = string.len
local str_byte = string.byte
local str_char = string.char
local str_format = string.format
local tbl_insert = table.insert
local tbl_concat = table.concat

local function json_encode (obj, state)
  if state == nil then
    state = {} 
  end
  local obj_type = type(obj)
  if obj_type == "string" then
    return '"' .. str_gsub(obj, '[%c\\"]', function(c)
      local b = str_byte(c)
      if b < 32 then
        if b == 8 then return '\\b' end
        if b == 9 then return '\\t' end
        if b == 10 then return '\\n' end
        if b == 12 then return '\\f' end
        if b == 13 then return '\\r' end
        return str_format('\\u%04x', b)
      end
      return '\\' .. c
    end) .. '"'
  elseif obj_type == "number" or obj_type == "boolean" then
    return tostring(obj)
  elseif obj_type == "table" then
    if state[obj] then error("circular reference") end
    state[obj] = true
    local res = {}
    local is_array = true
    local max_index = 0
    for k,v in pairs(obj) do
      if type(k) == "number" and k > 0 and math.floor(k) == k then
        if k > max_index then max_index = k end
      else
        is_array = false
      end
    end
    if is_array then
      for i = 1, max_index do
        if obj[i] == nil then
          is_array = false
          break
        end
      end
    end
    
    if is_array then
      for i = 1, max_index do
        tbl_insert(res, json_encode(obj[i], state))
      end
      state[obj] = nil
      return "[" .. tbl_concat(res, ",") .. "]"
    else
      for k,v in pairs(obj) do
        tbl_insert(res, json_encode(k, state) .. ":" .. json_encode(v, state))
      end
      state[obj] = nil
      return "{" .. tbl_concat(res, ",") .. "}"
    end
  else
    return "null"
  end
end

local function json_decode(str, pos, nullval)
  local pos = pos or 1
  local len = string.len(str)

  local function skip_whitespace()
    while pos <= len do
      local char = string.sub(str, pos, pos)
      if string.find(char, "%s") then
        pos = pos + 1
      else
        break
      end
    end
  end

  local function parse_value()
    skip_whitespace()
    if pos > len then return nil, "Unexpected end of input" end
    local char = string.sub(str, pos, pos)

    if char == "{" then
      return parse_object()
    elseif char == "[" then
      return parse_array()
    elseif char == '"' then
      return parse_string()
    elseif string.find(char, "[%-0-9]") then
      return parse_number()
    elseif char == "t" then
      if string.sub(str, pos, pos+3) == "true" then
        pos = pos + 4
        return true
      end
    elseif char == "f" then
      if string.sub(str, pos, pos+4) == "false" then
        pos = pos + 5
        return false
      end
    elseif char == "n" then
      if string.sub(str, pos, pos+3) == "null" then
        pos = pos + 4
        return nullval
      end
    end
    return nil, "Invalid JSON at position " .. pos
  end

  function parse_object()
    local obj = {}
    pos = pos + 1 -- skip {
    skip_whitespace()
    if string.sub(str, pos, pos) == "}" then
      pos = pos + 1
      return obj
    end

    while pos <= len do
      local key = parse_string()
      if not key then return nil, "Expected string key" end
      skip_whitespace()
      if string.sub(str, pos, pos) ~= ":" then return nil, "Expected colon" end
      pos = pos + 1
      local val = parse_value()
      obj[key] = val
      skip_whitespace()
      local next_char = string.sub(str, pos, pos)
      if next_char == "}" then
        pos = pos + 1
        return obj
      elseif next_char == "," then
        pos = pos + 1
        skip_whitespace()
      else
        return nil, "Expected comma or closing brace"
      end
    end
  end

  function parse_array()
    local arr = {}
    pos = pos + 1 -- skip [
    skip_whitespace()
    if string.sub(str, pos, pos) == "]" then
      pos = pos + 1
      return arr
    end

    local i = 1
    while pos <= len do
      local val = parse_value()
      arr[i] = val
      i = i + 1
      skip_whitespace()
      local next_char = string.sub(str, pos, pos)
      if next_char == "]" then
        pos = pos + 1
        return arr
      elseif next_char == "," then
        pos = pos + 1
        skip_whitespace()
      else
        return nil, "Expected comma or closing bracket"
      end
    end
  end

  function parse_string()
    if string.sub(str, pos, pos) ~= '"' then return nil end
    pos = pos + 1
    local start = pos
    while pos <= len do
      local char = string.sub(str, pos, pos)
      if char == '"' then
        local val = string.sub(str, start, pos - 1)
        pos = pos + 1
        return val
      elseif char == "\\" then
        pos = pos + 2
      else
        pos = pos + 1
      end
    end
    return nil
  end

  function parse_number()
    local start = pos
    if string.sub(str, pos, pos) == "-" then pos = pos + 1 end
    while pos <= len do
      local char = string.sub(str, pos, pos)
      if string.find(char, "[0-9%.]") then
        pos = pos + 1
      else
        break
      end
    end
    return tonumber(string.sub(str, start, pos - 1))
  end

  return parse_value()
end

-- Minimal DKJSON implementation/wrapper for typical OT usage
local json = {
  encode = json_encode,
  decode = json_decode
}

return json

