local fs = require("@lune/fs")
local luau = require("@lune/luau")

-- BITREADER_DEBUG = true
local deserialize = require("bytecode/deserialize")

local bytecode = luau.compile([[
    -- loadnil
    local a = nil

    -- loadb
    local b = true
    local c = false

    -- loadn
    local d = 88_998_844

    print(a,b,c,d)
]])

fs.writeFile("bytecode.bin", bytecode)

local result = deserialize(bytecode)

print(result)