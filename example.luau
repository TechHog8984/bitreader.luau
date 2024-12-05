local fs = require("@lune/fs")
local luau = require("@lune/luau")

-- BITREADER_DEBUG = true
local deserialize = require("luau/deserialize")
local disassemble = require("luau/disassemble")
local decompile = require("luau/decompiler/decompile")

local READ_ROBLOX_BYTECODE_FROM_FILE = false

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
        local d = 255

        -- loadk
        local e = 88_998_844
        local f = "hello"

        -- move
        local g = a

        -- getglobal & call
        print(a,b,c,d,e,f)

        -- setglobal
        global = a

        -- gettable
        a = global[a]

        -- settable
        global[b] = c

        -- gettableks
        a = global["hi"]

        -- settableks
        global["0"] = a

        -- gettablen
        a = global[200]

        -- settablen
        global[220] = a

        local function proto1()
            local a = 1
        end
        proto1()
        local d = proto1
        print(d)

        -- return func()
        -- return a + b, a - b, a * b, a / b, a // b, a % b, a ^ b, a .. b
        -- return a + 1, a - 1, a * 1, a / 1, a // 1, a % 1, a ^ 1
    
        return not a, -a, #a
    ]]
        ,{optimizationLevel = 0}
    )

    decode_code = nil
end

local proto = deserialize(bytecode, decode_code)

print("-- DISASSEMBLY:")
print(disassemble(proto))

print("\n--------------\n")

print("-- DECOMPILATION:")
print(decompile(proto))