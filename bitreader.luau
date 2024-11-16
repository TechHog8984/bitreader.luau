--[[
    bitreader.luau
    part of https://github.com/TechHog8984/bitreader.luau
    by techhog
    see LICENSE
]]

assert(buffer, "[bitreader] bitreader needs a 'buffer' global")
local bitreader = {}
local bitreader__mt = {
    __index = function(self, key)
        local value = bitreader[key]
        if value then
            return value
        end
        error("invalid key '" .. key .. "' to buffer")
    end,
    __newindex = function(self, key, value)
        error("invalid key '" .. key .. "' to buffer")
    end
}

local buffer_fromstring = buffer.fromstring
local buffer_tostring = buffer.tostring
local buffer_len = buffer.len
local buffer_readi8 = buffer.readi8
local buffer_readu8 = buffer.readu8
local buffer_readi16 = buffer.readi16
local buffer_readu16 = buffer.readu16
local buffer_readi32 = buffer.readi32
local buffer_readu32 = buffer.readu32
local buffer_readf32 = buffer.readf32
local buffer_readf64 = buffer.readf64
local buffer_readstring = buffer.readstring

local bor = bit32.bor
local lshift = bit32.lshift
local band = bit32.band

function bitreader.frombuffer(data: buffer, string_len_func: ( (...any) -> ...any )?)
    return setmetatable({
        size = buffer_len(data),
        data = data,
        offset = 0,
        _string_len_func = string_len_func or bitreader.readvarint
    }, bitreader__mt)
end
function bitreader.fromstring(data: string, ...)
    local data_buffer = buffer_fromstring(data)
    return bitreader.frombuffer(data_buffer, ...)
end

function bitreader:tostring()
    return buffer_tostring(self.data)
end
function bitreader:len()
    return self.size
end

function bitreader:readu8()
    local result = buffer_readu8(self.data, self.offset)
    self.offset += 1
    return result
end
function bitreader:readi8()
    local result = buffer_readi8(self.data, self.offset)
    self.offset += 1
    return result
end
function bitreader:readu16()
    local result = buffer_readu16(self.data, self.offset)
    self.offset += 2
    return result
end
function bitreader:readi16()
    local result = buffer_readi16(self.data, self.offset)
    self.offset += 2
    return result
end
function bitreader:readu32()
    local result = buffer_readu32(self.data, self.offset)
    self.offset += 4
    return result
end
function bitreader:readi32()
    local result = buffer_readi32(self.data, self.offset)
    self.offset += 4
    return result
end
function bitreader:readf32()
    local result = buffer_readf32(self.data, self.offset)
    self.offset += 4
    return result
end
function bitreader:readf64()
    local result = buffer_readf64(self.data, self.offset)
    self.offset += 8
    return result
end

function bitreader:readvarint()
    local result = 0;
    local shift = 0;

    local byte = 0

    repeat
        byte = self:readu8()
        result = bor(result, lshift(band(byte, 127), shift))
        shift += 7
    until band(byte, 128) == 0

    return result
end

function bitreader:readstring(length: number?)
    length = length or self:_string_len_func()
    local result = buffer_readstring(self.data, self.offset, length)
    self.offset += length
    return result
end

return bitreader
