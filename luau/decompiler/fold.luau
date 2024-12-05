--!strict

--[[
    luau/decompiler/fold.luau
    part of https://github.com/TechHog8984/bitreader.luau
    by techhog
    see LICENSE

    target luau version: 0.635
]]

local log: (...any) -> () = if BITREADER_DEBUG then print else function(...) end

local ast = require("ast")

type AstLocal = ast.AstLocal

type AstExpr = ast.AstExpr
type AstExprGroup = ast.AstExprGroup
type AstExprConstantNil = ast.AstExprConstantNil
type AstExprConstantBool = ast.AstExprConstantBool
type AstExprConstantNumber = ast.AstExprConstantNumber
type AstExprConstantString = ast.AstExprConstantString
type AstExprLocal = ast.AstExprLocal
type AstExprGlobal = ast.AstExprGlobal
type AstExprVarargs = ast.AstExprVarargs
type AstExprCall = ast.AstExprCall
type AstExprIndexName = ast.AstExprIndexName
type AstExprIndexExpr = ast.AstExprIndexExpr
type AstExprFunction = ast.AstExprFunction
type AstExprTable = ast.AstExprTable
type AstExprUnary = ast.AstExprUnary
type AstExprBinary = ast.AstExprBinary
type AstExprIfElse = ast.AstExprIfElse
type AstExprInterpString = ast.AstExprInterpString

type AstStat = ast.AstStat
type AstStatBlock = ast.AstStatBlock
type AstStatIf = ast.AstStatIf
type AstStatWhile = ast.AstStatWhile
type AstStatRepeat = ast.AstStatRepeat
type AstStatBreak = ast.AstStatBreak
type AstStatContinue = ast.AstStatContinue
type AstStatReturn = ast.AstStatReturn
type AstStatExpr = ast.AstStatExpr
type AstStatLocal = ast.AstStatLocal
type AstStatFor = ast.AstStatFor
type AstStatForIn = ast.AstStatForIn
type AstStatAssign = ast.AstStatAssign
type AstStatCompoundAssign = ast.AstStatCompoundAssign
type AstStatFunction = ast.AstStatFunction
type AstStatLocalFunction = ast.AstStatLocalFunction
type AstStatComment = ast.AstStatComment

-- modifies an AstStatBlock, handling discrepancies from bytecode not being 1:1 to ast
local function fold(stat: AstStatBlock)
    
end

return fold