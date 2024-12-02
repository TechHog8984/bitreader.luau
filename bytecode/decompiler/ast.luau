--!strict

--[[
    bytecode/decompiler/ast.luau
    part of https://github.com/TechHog8984/bitreader.luau
    by techhog
    see LICENSE

    target luau version: 0.635
]]

local log: (...any) -> () = if BITREADER_DEBUG then print else function(...) end

local common = require("../common")

local enum = common.enum

export type AstLocal = {
    name: string
}

type AstNode = {
    t: number,
    is_expr: boolean,
    is_stat: boolean
}

local AST_EXPR_GROUP = enum(0)
export type AstExprGroup = AstNode & {
    expr: AstExpr
}
local AST_EXPR_CONSTANT_NIL = enum()
export type AstExprConstantNil = AstNode & {}
local AST_EXPR_CONSTANT_BOOL = enum()
export type AstExprConstantBool = AstNode & {
    value: boolean
}
local AST_EXPR_CONSTANT_NUMBER = enum()
export type AstExprConstantNumber = AstNode & {
    value: number
}
local AST_EXPR_CONSTANT_STRING = enum()
export type AstExprConstantString = AstNode & {
    value: string
}

local AST_EXPR_LOCAL = enum()
export type AstExprLocal = AstNode & {
    l: AstLocal
}
local AST_EXPR_GLOBAL = enum()
export type AstExprGlobal = AstNode & {
    name: string
}

local AST_EXPR_VARARGS = enum()
export type AstExprVarargs = AstNode & {}

local AST_EXPR_CALL = enum()
export type AstExprCall = AstNode & {
    func: AstExpr,
    args: { AstExpr },
    self: boolean
}

local AST_EXPR_INDEX_NAME = enum()
export type AstExprIndexName = AstNode & {
    expr: AstExpr,
    index: string
}
local AST_EXPR_INDEX_EXPR = enum()
export type AstExprIndexExpr = AstNode & {
    expr: AstExpr,
    index: AstExpr
}

local AST_EXPR_FUNCTION = enum()
export type AstExprFunction = AstNode & {
    args: { AstLocal },
    vararg: boolean,
    body: { AstStatBlock }
}

local TABLE_ITEM_List = 0
local TABLE_ITEM_Record = 1
local TABLE_ITEM_General = 2
export type TableItem = {
    kind: number,
    key: AstExpr,
    value: AstExpr
}
local AST_EXPR_TABLE = enum()
export type AstExprTable = AstNode & {
    items: {TableItem}
}

local UNARY_Not = 0
local UNARY_Minus = 1
local UNARY_Len = 2
local AST_EXPR_UNARY = enum()
export type AstExprUnary = AstNode & {
    op: number,
    expr: AstExpr
}

local BINARY_Add = 0
local BINARY_Sub = 1
local BINARY_Mul = 2
local BINARY_Div = 3
local BINARY_FloorDiv = 4
local BINARY_Mod = 5
local BINARY_Pow = 6
local BINARY_Concat = 7
local BINARY_CompareNe = 8
local BINARY_CompareEq = 9
local BINARY_CompareLt = 10
local BINARY_CompareLe = 11
local BINARY_CompareGt = 12
local BINARY_CompareGe = 13
local BINARY_And = 14
local BINARY_Or = 15

local BINARY_Op__Count = 16

local AST_EXPR_BINARY = enum()
export type AstExprBinary = AstNode & {
    op: number,
    left: AstExpr,
    right: AstExpr
}

local AST_EXPR_IF_ELSE = enum()
export type AstExprIfElse = AstNode & {
    condition: AstExpr,
    -- TODO: rename to then and else
    true_expr: AstExpr,
    false_expr: AstExpr
}

local AST_EXPR_INTERP_STRING = enum()
export type AstExprInterpString = AstNode & {
    string_list: { string },
    expression_list: { AstExpr }
}

export type AstExpr = AstExprGroup | AstExprConstantNil | AstExprConstantBool |
    AstExprConstantNumber | AstExprConstantString | AstExprLocal | AstExprGlobal |
    AstExprVarargs | AstExprCall | AstExprIndexName | AstExprIndexExpr |
    AstExprFunction | AstExprTable | AstExprUnary | AstExprBinary | AstExprIfElse |
    AstExprInterpString

local AST_STAT_BLOCK = enum()
export type AstStatBlock = AstNode & {
    body: { AstStat }
}

local AST_STAT_IF = enum()
export type AstStatIf = AstNode & {
    condition: AstExpr,
    then_body: AstStatBlock,
    else_body: AstStat
}

local AST_STAT_WHILE = enum()
export type AstStatWhile = AstNode & {
    condition: AstExpr,
    body: AstStatBlock
}

local AST_STAT_REPEAT = enum()
export type AstStatRepeat = AstNode & {
    condition: AstExpr,
    body: AstStatBlock
}

local AST_STAT_BREAK = enum()
export type AstStatBreak = AstNode & {}
local AST_STAT_CONTINUE = enum()
export type AstStatContinue = AstNode & {}

local AST_STAT_RETURN = enum()
export type AstStatReturn = AstNode & {
    list: { AstExpr }
}

local AST_STAT_EXPR = enum()
export type AstStatExpr = AstNode & {
    expr: AstExpr
}

local AST_STAT_LOCAL = enum()
export type AstStatLocal = AstNode & {
    vars: { AstLocal },
    values: { AstExpr }
}

local AST_STAT_FOR = enum()
export type AstStatFor = AstNode & {
    var: AstLocal,
    from: AstExpr,
    to: AstExpr,
    step: AstExpr,
    body: AstStatBlock
}
local AST_STAT_FOR_IN = enum()
export type AstStatForIn = AstNode & {
    vars: { AstLocal },
    values: { AstExpr },
    body: AstStatBlock
}

local AST_STAT_ASSIGN = enum()
export type AstStatAssign = AstNode & {
    vars: { AstExpr },
    values: { AstExpr }
}
local AST_STAT_COMPOUND_ASSIGN = enum()
export type AstStatCompoundAssign = AstNode & {
    op: number,
    var: AstExpr,
    value: AstExpr
}

local AST_STAT_FUNCTION = enum()
export type AstStatFunction = AstNode & {
    name: AstExpr,
    func: AstExprFunction
}

local AST_STAT_LOCAL_FUNCTION = enum()
export type AstStatLocalFunction = AstNode & {
    name: AstExpr,
    func: AstExprFunction
}

export type AstStat = AstStatBlock | AstStatIf | AstStatWhile | AstStatRepeat |
    AstStatBreak | AstStatContinue | AstStatReturn | AstStatExpr | AstStatLocal |
    AstStatFor | AstStatForIn | AstStatAssign | AstStatCompoundAssign |
    AstStatFunction | AstStatLocalFunction

local function astToString(node: AstNode): string
    if node.is_expr then
        if node.t == AST_EXPR_GROUP then
        elseif node.t == AST_EXPR_CONSTANT_NIL then
        elseif node.t == AST_EXPR_CONSTANT_BOOL then
        elseif node.t == AST_EXPR_CONSTANT_NUMBER then
        elseif node.t == AST_EXPR_CONSTANT_STRING then
        elseif node.t == AST_EXPR_LOCAL then
        elseif node.t == AST_EXPR_GLOBAL then
        elseif node.t == AST_EXPR_VARARGS then
        elseif node.t == AST_EXPR_CALL then
        elseif node.t == AST_EXPR_INDEX_NAME then
        elseif node.t == AST_EXPR_INDEX_EXPR then
        elseif node.t == AST_EXPR_FUNCTION then
        elseif node.t == AST_EXPR_TABLE then
        elseif node.t == AST_EXPR_UNARY then
        elseif node.t == AST_EXPR_BINARY then
        elseif node.t == AST_EXPR_IF_ELSE then
        elseif node.t == AST_EXPR_INTERP_STRING then
        end

        error("unknown expression type " .. node.t)
    elseif node.is_stat then
        if node.t == AST_STAT_BLOCK then
        elseif node.t == AST_STAT_IF then
        elseif node.t == AST_STAT_WHILE then
        elseif node.t == AST_STAT_REPEAT then
        elseif node.t == AST_STAT_BREAK then
        elseif node.t == AST_STAT_CONTINUE then
        elseif node.t == AST_STAT_RETURN then
        elseif node.t == AST_STAT_EXPR then
        elseif node.t == AST_STAT_LOCAL then
        elseif node.t == AST_STAT_FOR then
        elseif node.t == AST_STAT_FOR_IN then
        elseif node.t == AST_STAT_ASSIGN then
        elseif node.t == AST_STAT_COMPOUND_ASSIGN then
        elseif node.t == AST_STAT_FUNCTION then
        elseif node.t == AST_STAT_LOCAL_FUNCTION then
        end

        error("unknown stat type " .. node.t)
    end

    error("expected is_expr or is_stat")
end

return {
    astToString = astToString
}