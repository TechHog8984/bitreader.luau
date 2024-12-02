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
local formatString = common.formatString

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

local TABLE_ITEM_List = 0     -- foo, (key is nil)
local TABLE_ITEM_Record = 1   -- foo=bar, (key is AstExprConstantString)
local TABLE_ITEM_General = 2  -- [foo]=bar
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

local astToString: ( node: AstNode ) -> string

local function arrayToString(array: { any }, format: ( any ) -> string): string
    local result = ""

    for _, v in array do
        result ..= format(v) .. ", "
    end

    return result:sub(1, -3)
end

local function nodeArrayToString(array: { AstNode }): string
    return arrayToString(array, astToString)
end

local function localToString(l: AstLocal): string
    return l.name
end
local function localArrayToString(array: { AstLocal }): string
    return arrayToString(array, localToString)
end

local function statArrayToString(array: { AstStat }): string
    local result = ""

    for _, stat in array do
        result ..= astToString(stat) .. '\n'
    end

    return result:sub(1, -2)
end

local function tableItemToString(item: TableItem): string
    if item.kind == TABLE_ITEM_List then
        return astToString(item.value)
    elseif item.kind == TABLE_ITEM_Record then
        return (item.key::AstExprConstantString).value .. " = " .. astToString(item.value)
    elseif item.kind == TABLE_ITEM_General then
        return '[' .. astToString(item.key) .. '] = ' .. astToString(item.value)
    end
    error("invalid item kind " .. tostring(item.kind))
end
local function tableItemArrayToString(array: { TableItem }): string
    local result = ""

    for _, item in array do
        result ..= tableItemToString(item) .. ",\n"
    end

    return result:sub(1, -3)
end

local function functionToString(func: AstExprFunction, name: string?): string
    local args = '(' .. localArrayToString(func.args)
    args..= if func.vararg then "...)" else ')'
    return "function" .. (if name then " " .. name else '') .. args.. '\n' ..
        statArrayToString(func.body) .. "\nend"
end

local UNARY_TOSTRING_MAP: { [number]: string} = {
    [UNARY_Not] = "not",
    [UNARY_Minus] = "-\z",
    [UNARY_Len] = "#\z"
}
local BINARY_TOSTRING_MAP: { [number]: string} = {
    [BINARY_Add] = '+',
    [BINARY_Sub] = '-',
    [BINARY_Mul] = '*',
    [BINARY_Div] = '/',
    [BINARY_FloorDiv] = "//",
    [BINARY_Mod] = '%',
    [BINARY_Pow] = '^',
    [BINARY_Concat] = "..",
    [BINARY_CompareNe] = "~=",
    [BINARY_CompareEq] = "==",
    [BINARY_CompareLt] = '<',
    [BINARY_CompareLe] = "<=",
    [BINARY_CompareGt] = '>',
    [BINARY_CompareGe] = ">=",
    [BINARY_And] = "and",
    [BINARY_Or] = "or"
}
astToString = function(node: AstNode): string
    if node.is_expr then
        if node.t == AST_EXPR_GROUP then
            local expr_group = node :: AstExprGroup
            return '(' .. astToString(expr_group.expr) .. ')'
        elseif node.t == AST_EXPR_CONSTANT_NIL then
            return "nil"
        elseif node.t == AST_EXPR_CONSTANT_BOOL then
            local expr_constant_bool = node :: AstExprConstantBool
            return if expr_constant_bool.value then "true" else "false"
        elseif node.t == AST_EXPR_CONSTANT_NUMBER then
            local expr_constant_number = node :: AstExprConstantNumber
            return tostring(expr_constant_number.value)
        elseif node.t == AST_EXPR_CONSTANT_STRING then
            local expr_constant_string = node :: AstExprConstantString
            return formatString(expr_constant_string.value)
        elseif node.t == AST_EXPR_LOCAL then
            local expr_local = node :: AstExprLocal
            return expr_local.l.name
        elseif node.t == AST_EXPR_GLOBAL then
            local expr_global = node :: AstExprGlobal
            return expr_global.name
        elseif node.t == AST_EXPR_VARARGS then
            return "..."
        elseif node.t == AST_EXPR_CALL then
            local expr_call = node :: AstExprCall
            local args = nodeArrayToString(expr_call.args)
            return astToString(expr_call.func) .. '(' .. args .. ')'
        elseif node.t == AST_EXPR_INDEX_NAME then
            local expr_index_name = node :: AstExprIndexName
            return astToString(expr_index_name.expr) .. '.' .. expr_index_name.index
        elseif node.t == AST_EXPR_INDEX_EXPR then
            local expr_index_expr = node :: AstExprIndexExpr
            return astToString(expr_index_expr.expr) .. '[' .. astToString(expr_index_expr.index) .. ']'
        elseif node.t == AST_EXPR_FUNCTION then
            local expr_function = node :: AstExprFunction
            return functionToString(expr_function)
        elseif node.t == AST_EXPR_TABLE then
            local expr_table = node :: AstExprTable
            return '{' .. tableItemArrayToString(expr_table.items) .. '}'
        elseif node.t == AST_EXPR_UNARY then
            local expr_unary = node :: AstExprUnary
            return UNARY_TOSTRING_MAP[expr_unary.op] .. ' ' ..
                astToString(expr_unary.expr)
        elseif node.t == AST_EXPR_BINARY then
            local expr_binary = node :: AstExprBinary
            return astToString(expr_binary.left) .. ' ' ..
                BINARY_TOSTRING_MAP[expr_binary.op] .. ' ' ..
                astToString(expr_binary.right)
        elseif node.t == AST_EXPR_IF_ELSE then
            local expr_if_else = node :: AstExprIfElse
            return "if " .. astToString(expr_if_else.condition) .. " then " ..
                astToString(expr_if_else.true_expr) .. " else " .. astToString(expr_if_else.false_expr)
        elseif node.t == AST_EXPR_INTERP_STRING then
            local expr_interp_string = node :: AstExprInterpString
            local result = '`'

            local last = 1 
            for i = 1, #expr_interp_string.string_list - 1 do
                last = i + 1
                result ..= formatString(expr_interp_string.string_list[i], true)
                result ..= '{' .. astToString(expr_interp_string.expression_list[i]) .. '}'
            end
            result ..= formatString(expr_interp_string.string_list[last], true)

            return result .. '`'
        end

        error("unknown expression type " .. node.t)
    elseif node.is_stat then
        if node.t == AST_STAT_BLOCK then
            local stat_block = node :: AstStatBlock
            return statArrayToString(stat_block.body)
        elseif node.t == AST_STAT_IF then
            local stat_if = node :: AstStatIf
            return "if " .. astToString(stat_if.condition) .. " then\n" ..
                astToString(stat_if.then_body) ..
                (if stat_if.else_body then '\n' .. astToString(stat_if.else_body) else '') ..
                "\nend"
        elseif node.t == AST_STAT_WHILE then
            local stat_while = node :: AstStatWhile
            return "while " .. astToString(stat_while.condition) .. "do\n" ..
                astToString(stat_while.body) .. "\nend"
        elseif node.t == AST_STAT_REPEAT then
            local stat_repeat = node :: AstStatRepeat
            return "repeat\n" .. astToString(stat_repeat.body) .. "\n until " ..
                astToString(stat_repeat.condition)
        elseif node.t == AST_STAT_BREAK then
            return "break"
        elseif node.t == AST_STAT_CONTINUE then
            return "continue"
        elseif node.t == AST_STAT_RETURN then
            local stat_return = node :: AstStatReturn
            return "return " .. nodeArrayToString(stat_return.list) 
        elseif node.t == AST_STAT_EXPR then
            local expr = (node::AstStatExpr).expr
            return (if expr.t == AST_EXPR_GROUP then ';' else '') ..
                astToString(expr)
        elseif node.t == AST_STAT_LOCAL then
            local stat_local = node :: AstStatLocal
            return "local " .. localArrayToString(stat_local.vars) .. " = " ..
                nodeArrayToString(stat_local.values)
        elseif node.t == AST_STAT_FOR then
            local stat_for = node :: AstStatFor
            return "for " .. localToString(stat_for.var) .. " = " ..
                astToString(stat_for.from) .. ", " .. astToString(stat_for.to) ..
                if stat_for.step then astToString(stat_for.step) else '' ..
                " do\n" .. astToString(stat_for.body) .. "\nend"
        elseif node.t == AST_STAT_FOR_IN then
            local stat_for_in = node :: AstStatForIn
            return "for " .. localArrayToString(stat_for_in.vars) .. ", " ..
                nodeArrayToString(stat_for_in.values) .. " do\n" ..
                astToString(stat_for_in.body) .. "\nend"
        elseif node.t == AST_STAT_ASSIGN then
            local stat_assign = node :: AstStatAssign
            return nodeArrayToString(stat_assign.vars) .. " = " ..
                nodeArrayToString(stat_assign.values)
        elseif node.t == AST_STAT_COMPOUND_ASSIGN then
            local stat_compound_assign = node :: AstStatCompoundAssign
            return astToString(stat_compound_assign.var) .. BINARY_TOSTRING_MAP[stat_compound_assign.op] ..
                astToString(stat_compound_assign.value)
        elseif node.t == AST_STAT_FUNCTION then
            local stat_function = node :: AstStatFunction
            return functionToString(stat_function.func, astToString(stat_function.name))
        elseif node.t == AST_STAT_LOCAL_FUNCTION then
            local stat_local_function = node :: AstStatLocalFunction
            return "local " .. functionToString(stat_local_function.func, astToString(stat_local_function.name))
        end

        error("unknown stat type " .. node.t)
    end

    error("expected is_expr or is_stat")
end

return {
    astToString = astToString
}