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

        -- newclosure
        local function proto1()
            local a = 1
        end

        -- add, sub, mul, div, floordiv, mod, pow, concat
        local a1,a2,a3,a4,a5,a6,a7,a8 = a + b, a - b, a * b, a / b, a // b, a % b, a ^ b, a .. b
        -- addk, subk, mulk, divk, floordivk, modk, powk,
        local b1,b2,b3,b4,b5,b6,b7 = a + 1, a - 1, a * 1, a / 1, a // 1, a % 1, a ^ 1

        -- not, minus, length
        local c1,c2,c3 = not a, -a, #a

        -- newtable, setlist
        a = {1,2,3}

        -- getvarargs
        a = ...

        -- newtable, setlist multret, getvarargs multret
        a = {...}

        -- return, call
        return proto1()
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