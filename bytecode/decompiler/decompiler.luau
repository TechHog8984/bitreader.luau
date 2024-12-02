--!strict

--[[
    bytecode/decompiler/decompiler.luau
    part of https://github.com/TechHog8984/bitreader.luau
    by techhog
    see LICENSE

    target luau version: 0.635
]]

local log: (...any) -> () = if BITREADER_DEBUG then print else function(...) end

local deserialize = require("../deserialize")
local common = require("../common")
local ast = require("ast")

local tryToGetProto = common.tryToGetProto

local astToString = ast.astToString

type Proto = common.Proto

type AstStat = ast.AstStat

local function decompileProto(proto: Proto): AstStat
    log("proto", proto)

    local result = {}

    return result
end
local function decompile(arg1: string | Proto): string
    local proto = tryToGetProto(arg1, deserialize)
    local ast_stat = decompileProto(proto)

    return astToString(ast_stat)
end

return decompile