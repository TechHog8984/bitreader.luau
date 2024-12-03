local fs = require("@lune/fs")
local luau = require("@lune/luau")

-- BITREADER_DEBUG = true
local deserialize = require("bytecode/deserialize")
local disassemble = require("bytecode/disassemble")
local decompile = require("bytecode/decompiler/decompile")

local READ_ROBLOX_BYTECODE_FROM_FILE = true

local decode_code: string?
local bytecode: string

if READ_ROBLOX_BYTECODE_FROM_FILE then
    bytecode = fs.readFile("bytecode.bin")
    decode_code = "op_mul_227"
else
    bytecode = luau.compile([[
        -- loadnil
        local a = nil
    
        -- loadb
        local b = true
        local c = false
    
        -- loadn
        local d = 88_998_844
    
        print(a,b,c,d)
    ]])
    decode_code = nil
end

local proto = deserialize(bytecode, decode_code)

print("-- DISASSEMBLY:")
print(disassemble(proto))

print("\n--------------\n")

print("-- DECOMPILATION:")
print(decompile(proto))