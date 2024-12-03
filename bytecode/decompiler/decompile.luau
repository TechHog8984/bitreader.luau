--!strict

--[[
    bytecode/decompiler/decompile.luau
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

local TABLE_ITEM_List = ast.TABLE_ITEM_List
local TABLE_ITEM_Record = ast.TABLE_ITEM_Record
local TABLE_ITEM_General = ast.TABLE_ITEM_General

local UNARY_Not = ast.UNARY_Not
local UNARY_Minus = ast.UNARY_Minus
local UNARY_Len = ast.UNARY_Len

local BINARY_Add = ast.BINARY_Add
local BINARY_Sub = ast.BINARY_Sub
local BINARY_Mul = ast.BINARY_Mul
local BINARY_Div = ast.BINARY_Div
local BINARY_FloorDiv = ast.BINARY_FloorDiv
local BINARY_Mod = ast.BINARY_Mod
local BINARY_Pow = ast.BINARY_Pow
local BINARY_Concat = ast.BINARY_Concat
local BINARY_CompareNe = ast.BINARY_CompareNe
local BINARY_CompareEq = ast.BINARY_CompareEq
local BINARY_CompareLt = ast.BINARY_CompareLt
local BINARY_CompareLe = ast.BINARY_CompareLe
local BINARY_CompareGt = ast.BINARY_CompareGt
local BINARY_CompareGe = ast.BINARY_CompareGe
local BINARY_And = ast.BINARY_And
local BINARY_Or = ast.BINARY_Or

local astToString = ast.astToString

local newAstLocal = ast.newAstLocal

local newAstExprGroup = ast.newAstExprGroup
local newAstExprConstantNil = ast.newAstExprConstantNil
local newAstExprConstantBool = ast.newAstExprConstantBool
local newAstExprConstantNumber = ast.newAstExprConstantNumber
local newAstExprConstantString = ast.newAstExprConstantString
local newAstExprLocal = ast.newAstExprLocal
local newAstExprGlobal = ast.newAstExprGlobal
local newAstExprVarargs = ast.newAstExprVarargs
local newAstExprCall = ast.newAstExprCall
local newAstExprIndexName = ast.newAstExprIndexName
local newAstExprIndexExpr = ast.newAstExprIndexExpr
local newAstExprFunction = ast.newAstExprFunction
local newAstExprTable = ast.newAstExprTable local newTableItem = ast.newTableItem
local newAstExprUnary = ast.newAstExprUnary
local newAstExprBinary = ast.newAstExprBinary
local newAstExprIfElse = ast.newAstExprIfElse
local newAstExprInterpString = ast.newAstExprInterpString

local newAstStatBlock = ast.newAstStatBlock
local newAstStatIf = ast.newAstStatIf
local newAstStatWhile = ast.newAstStatWhile
local newAstStatRepeat = ast.newAstStatRepeat
local newAstStatBreak = ast.newAstStatBreak
local newAstStatContinue = ast.newAstStatContinue
local newAstStatReturn = ast.newAstStatReturn
local newAstStatExpr = ast.newAstStatExpr
local newAstStatLocal = ast.newAstStatLocal
local newAstStatFor = ast.newAstStatFor
local newAstStatForIn = ast.newAstStatForIn
local newAstStatAssign = ast.newAstStatAssign
local newAstStatCompoundAssign = ast.newAstStatCompoundAssign
local newAstStatFunction = ast.newAstStatFunction
local newAstStatLocalFunction = ast.newAstStatLocalFunction

type Proto = common.Proto

type AstStatBlock = ast.AstStatBlock

local function decompileProto(proto: Proto): AstStatBlock
    log("proto", proto)

    local body = {}
    local result = newAstStatBlock(body)

    return result
end
local function decompile(arg1: string | Proto): string
    local proto = tryToGetProto(arg1, deserialize)
    local ast_stat = decompileProto(proto)

    return astToString(ast_stat)
end

return decompile