local fs = require("@lune/fs")
local luau = require("@lune/luau")

-- BITREADER_DEBUG = true
local deserialize = require("bytecode/deserialize")
local disassemble = require("bytecode/disassemble")
local decompile = require("bytecode/decompiler/decompile")

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

-- local bytecode = fs.readFile("bytecode.bin")

local proto = deserialize(bytecode, "op_mul_227")

print("-- DISASSEMBLY:")
print(disassemble(proto))

print("\n--------------\n")

print("-- DECOMPILATION:")
print(decompile(proto))