--!strict

--[[
    luau/decompiler/ast.luau
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

local function expectArg(value: any?, expected_type: string, argument: number)
    local value_type = type(value)
    if value_type == expected_type then
        return
    end
    error("invalid argument #" .. argument .. ": " .. expected_type .. " expected; got " .. value_type)
end
local function expectExpression(value: any?, argument: number)
    expectArg(value, "table", argument)
    if (value::AstNode).is_stat then
        error("invalid argument #" .. argument .. ": expr expected; got stat")
    end
    if not (value::AstNode).is_expr then
        error("invalid argument #" .. argument .. ": expr expected; got unknown")
    end
end
local function expectStat(value: any?, argument: number)
    expectArg(value, "table", argument)
    if (value::AstNode).is_expr then
        error("invalid argument #" .. argument .. ": stat expected; got expr")
    end
    if not (value::AstNode).is_stat then
        error("invalid argument #" .. argument .. ": stat expected; got unknown")
    end
end
local function expectLocal(value: any?, argument: number)
    expectArg(value, "table", argument)
    if not (value::AstLocal).name then
        error("invalid argument #" .. argument .. ": local expected; got unknown")
    end
end

local function newAstLocal(name: string): AstLocal
    expectArg(name, "string", 1)
    return {
        name = name
    }
end
local function newNode(t: number, is_expr: boolean): AstNode
    expectArg(t, "number", 1)
    expectArg(is_expr, "boolean", 2)

    return {
        t = t,
        is_expr = is_expr,
        is_stat = not is_expr
    }
end
local function newExpr(t: number): AstExpr
    local expr = newNode(t, true)
    return expr
end
local function newStat(t: number): AstStat
    local stat = newNode(t, false)
    return stat
end

local AST_EXPR_GROUP = enum(0)
export type AstExprGroup = AstNode & {
    expr: AstExpr
}
local function newAstExprGroup(expr: AstExpr): AstExprGroup
    expectExpression(expr, 1)
    local node = newExpr(AST_EXPR_GROUP) :: AstExprGroup
    node.expr = expr
    return node
end
local AST_EXPR_CONSTANT_NIL = enum()
export type AstExprConstantNil = AstNode & {}
local function newAstExprConstantNil(): AstExprConstantNil
    return newExpr(AST_EXPR_CONSTANT_NIL)
end
local AST_EXPR_CONSTANT_BOOL = enum()
export type AstExprConstantBool = AstNode & {
    value: boolean
}
local function newAstExprConstantBool(value: boolean): AstExprConstantBool
    expectArg(value, "boolean", 1)
    local node = newExpr(AST_EXPR_CONSTANT_BOOL) :: AstExprConstantBool
    node.value = value
    return node
end
local AST_EXPR_CONSTANT_NUMBER = enum()
export type AstExprConstantNumber = AstNode & {
    value: number
}
local function newAstExprConstantNumber(value: number): AstExprConstantNumber
    expectArg(value, "number", 1)
    local node = newExpr(AST_EXPR_CONSTANT_NUMBER) :: AstExprConstantNumber
    node.value = value
    return node
end
local AST_EXPR_CONSTANT_STRING = enum()
export type AstExprConstantString = AstNode & {
    value: string
}
local function newAstExprConstantString(value: string): AstExprConstantString
    expectArg(value, "string", 1)
    local node = newExpr(AST_EXPR_CONSTANT_STRING) :: AstExprConstantString
    node.value = value
    return node
end

local AST_EXPR_LOCAL = enum()
export type AstExprLocal = AstNode & {
    l: AstLocal
}
local function newAstExprLocal(l: AstLocal): AstExprLocal
    expectLocal(l, 1)
    local node = newExpr(AST_EXPR_LOCAL) :: AstExprLocal
    node.l = l
    return node
end
local AST_EXPR_GLOBAL = enum()
export type AstExprGlobal = AstNode & {
    name: string
}
local function newAstExprGlobal(name: string): AstExprGlobal
    expectArg(name, "string", 1)
    local node = newExpr(AST_EXPR_GLOBAL) :: AstExprGlobal
    node.name = name
    return node
end

local AST_EXPR_VARARGS = enum()
export type AstExprVarargs = AstNode & {}
local function newAstExprVarargs(): AstExprVarargs
    return newExpr(AST_EXPR_VARARGS)
end

local AST_EXPR_CALL = enum()
export type AstExprCall = AstNode & {
    func: AstExpr,
    args: { AstExpr },
    self: boolean
}
local function newAstExprCall(func: AstExpr, args: { AstExpr }, self: boolean): AstExprCall
    expectExpression(func, 1)
    expectArg(args, "table", 2)
    expectArg(self, "boolean", 3)
    local node = newExpr(AST_EXPR_CALL) :: AstExprCall
    node.func = func
    node.args = args
    node.self = self
    return node
end

local AST_EXPR_INDEX_NAME = enum()
export type AstExprIndexName = AstNode & {
    expr: AstExpr,
    index: string
}
local function newAstExprIndexName(expr: AstExpr, index: string): AstExprIndexName
    expectExpression(expr, 1)
    expectArg(index, "string", 2)
    local node = newExpr(AST_EXPR_INDEX_NAME) :: AstExprIndexName
    node.expr = expr
    node.index = index
    return node
end
local AST_EXPR_INDEX_EXPR = enum()
export type AstExprIndexExpr = AstNode & {
    expr: AstExpr,
    index: AstExpr
}
local function newAstExprIndexExpr(expr: AstExpr, index: AstExpr): AstExprIndexExpr
    expectExpression(expr, 1)
    expectExpression(index, 2)
    local node = newExpr(AST_EXPR_INDEX_EXPR) :: AstExprIndexExpr
    node.expr = expr
    node.index = index
    return node
end

local AST_EXPR_FUNCTION = enum()
export type AstExprFunction = AstNode & {
    args: { AstLocal },
    vararg: boolean,
    body: AstStatBlock
}
local function newAstExprFunction(args: { AstLocal }, vararg: boolean, body: AstStatBlock): AstExprFunction
    expectArg(args, "table", 1)
    expectArg(vararg, "boolean", 2)
    expectArg(body, "table", 3)
    local node = newExpr(AST_EXPR_FUNCTION) :: AstExprFunction
    node.args = args
    node.vararg = vararg
    node.body = body
    return node
end

local TABLE_ITEM_List = 0     -- foo, (key is nil)
local TABLE_ITEM_Record = 1   -- foo=bar, (key is AstExprConstantString)
local TABLE_ITEM_General = 2  -- [foo]=bar
export type TableItem = {
    kind: number,
    key: AstExpr,
    value: AstExpr
}
local function newTableItem(kind: number, key: AstExpr, value: AstExpr): TableItem
    expectArg(kind, "number", 1)
    expectExpression(key, 2)
    expectExpression(value, 3)
    return {
        kind = kind,
        key = key,
        value = value
    }
end
local AST_EXPR_TABLE = enum()
export type AstExprTable = AstNode & {
    items: { TableItem }
}
local function newAstExprTable(items: { TableItem }): AstExprTable
    expectArg(items, "table", 1)
    local node = newExpr(AST_EXPR_TABLE) :: AstExprTable
    node.items = items
    return node
end

local UNARY_Not = 0
local UNARY_Minus = 1
local UNARY_Len = 2
local AST_EXPR_UNARY = enum()
export type AstExprUnary = AstNode & {
    op: number,
    expr: AstExpr
}
local function newAstExprUnary(op: number, expr: AstExpr): AstExprUnary
    expectArg(op, "number", 1)
    expectExpression(expr, 2)
    local node = newExpr(AST_EXPR_UNARY) :: AstExprUnary
    node.op = op
    node.expr = expr
    return node
end

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
local function newAstExprBinary(op: number, left: AstExpr, right: AstExpr): AstExprBinary
    expectArg(op, "number", 1)
    expectExpression(left, 2)
    expectExpression(right, 3)
    local node = newExpr(AST_EXPR_BINARY) :: AstExprBinary
    node.op = op
    node.left = left
    node.right = right
    return node
end

local AST_EXPR_IF_ELSE = enum()
export type AstExprIfElse = AstNode & {
    condition: AstExpr,
    -- TODO: rename to then and else
    true_expr: AstExpr,
    false_expr: AstExpr
}
local function newAstExprIfElse(condition: AstExpr, true_expr: AstExpr, false_expr: AstExpr): AstExprIfElse
    expectExpression(condition, 1)
    expectExpression(true_expr, 2)
    expectExpression(false_expr, 3)
    local node = newExpr(AST_EXPR_IF_ELSE) :: AstExprIfElse
    node.condition = condition
    node.true_expr = true_expr
    node.false_expr = false_expr
    return node
end

local AST_EXPR_INTERP_STRING = enum()
export type AstExprInterpString = AstNode & {
    string_list: { string },
    expression_list: { AstExpr }
}
local function newAstExprInterpString(string_list: { string }, expression_list: { AstExpr }): AstExprInterpString
    expectArg(string_list, "table", 1)
    expectArg(expression_list, "table", 2)
    local node = newExpr(AST_EXPR_INTERP_STRING) :: AstExprInterpString
    node.string_list = string_list
    node.expression_list = expression_list
    return node
end


local AST_EXPR_TOP = enum()
export type AstExprTop = AstNode & { }
local function newAstExprTop(): AstExprTop
    return newExpr(AST_EXPR_TOP)
end

export type AstExpr = AstExprGroup | AstExprConstantNil | AstExprConstantBool |
    AstExprConstantNumber | AstExprConstantString | AstExprLocal | AstExprGlobal |
    AstExprVarargs | AstExprCall | AstExprIndexName | AstExprIndexExpr |
    AstExprFunction | AstExprTable | AstExprUnary | AstExprBinary | AstExprIfElse |
    AstExprInterpString | AstExprTop

local AST_STAT_BLOCK = enum()
export type AstStatBlock = AstNode & {
    body: { AstStat }
}
local function newAstStatBlock(body: { AstStat }): AstStatBlock
    expectArg(body, "table", 1)
    local node = newStat(AST_STAT_BLOCK) :: AstStatBlock
    node.body = body
    return node
end

local AST_STAT_IF = enum()
export type AstStatIf = AstNode & {
    condition: AstExpr,
    then_body: AstStatBlock,
    else_body: AstStat?
}
local function newAstStatIf(condition: AstExpr, then_body: AstStatBlock, else_body: AstStat?): AstStat
    expectExpression(condition, 1)
    expectStat(then_body, 2)
    if else_body then expectStat(else_body, 3) end
    local node = newStat(AST_STAT_IF) :: AstStatIf
    node.condition = condition
    node.then_body = then_body
    node.else_body = else_body
    return node
end

local AST_STAT_WHILE = enum()
export type AstStatWhile = AstNode & {
    condition: AstExpr,
    body: AstStatBlock
}
local function newAstStatWhile(condition: AstExpr, body: AstStatBlock): AstStatWhile
    expectExpression(condition, 1)
    expectStat(body, 2)
    local node = newStat(AST_STAT_WHILE) :: AstStatWhile
    node.condition = condition
    node.body = body
    return node
end

local AST_STAT_REPEAT = enum()
export type AstStatRepeat = AstNode & {
    condition: AstExpr,
    body: AstStatBlock
}
local function newAstStatRepeat(condition: AstExpr, body: AstStatBlock): AstStatRepeat
    expectExpression(condition, 1)
    expectStat(body, 2)
    local node = newStat(AST_STAT_REPEAT) :: AstStatRepeat
    node.condition = condition
    node.body = body
    return node
end

local AST_STAT_BREAK = enum()
export type AstStatBreak = AstNode & {}
local function newAstStatBreak(): AstStatBreak
    return newStat(AST_STAT_BREAK)
end
local AST_STAT_CONTINUE = enum()
export type AstStatContinue = AstNode & {}
local function newAstStatContinue(): AstStatContinue
    return newStat(AST_STAT_CONTINUE)
end

local AST_STAT_RETURN = enum()
export type AstStatReturn = AstNode & {
    list: { AstExpr }
}
local function newAstStatReturn(list: { AstExpr }): AstStatReturn
    expectArg(list, "table", 1)
    local node = newStat(AST_STAT_RETURN) :: AstStatReturn
    node.list = list
    return node
end

local AST_STAT_EXPR = enum()
export type AstStatExpr = AstNode & {
    expr: AstExpr
}
local function newAstStatExpr(expr: AstExpr): AstStatExpr
    expectExpression(expr, 1)
    local node = newStat(AST_STAT_EXPR) :: AstStatExpr
    node.expr = expr
    return node
end

local AST_STAT_LOCAL = enum()
export type AstStatLocal = AstNode & {
    vars: { AstLocal },
    values: { AstExpr }
}
local function newAstStatLocal(vars: { AstLocal }, values: { AstExpr }): AstStatLocal
    expectArg(vars, "table", 1)
    expectArg(values, "table", 2)
    local node = newStat(AST_STAT_LOCAL) :: AstStatLocal
    node.vars = vars
    node.values = values
    return node
end

local AST_STAT_FOR = enum()
export type AstStatFor = AstNode & {
    var: AstLocal,
    from: AstExpr,
    to: AstExpr,
    step: AstExpr?,
    body: AstStatBlock
}
local function newAstStatFor(var: AstLocal, from: AstExpr, to: AstExpr, step: AstExpr?, body: AstStatBlock): AstStatFor
    expectLocal(var, 1)
    expectExpression(from, 2)
    expectExpression(to, 3)
    if step then expectExpression(step, 4) end
    expectStat(body, 5)
    local node = newStat(AST_STAT_FOR) :: AstStatFor
    node.var = var
    node.from = from
    node.to = to
    node.step = step
    node.body = body
    return node
end
local AST_STAT_FOR_IN = enum()
export type AstStatForIn = AstNode & {
    vars: { AstLocal },
    values: { AstExpr },
    body: AstStatBlock
}
local function newAstStatForIn(vars: { AstLocal }, values: { AstExpr }, body: AstStatBlock): AstStatForIn
    expectArg(vars, "table", 1)
    expectArg(values, "table", 2)
    expectStat(body, 3)
    local node = newStat(AST_STAT_FOR_IN) :: AstStatForIn
    node.vars = vars
    node.values = values
    node.body = body
    return node
end

local AST_STAT_ASSIGN = enum()
export type AstStatAssign = AstNode & {
    vars: { AstExpr },
    values: { AstExpr }
}
local function newAstStatAssign(vars: { AstExpr }, values: { AstExpr }): AstStatAssign
    expectArg(vars, "table", 1)
    expectArg(values, "table", 2)
    local node = newStat(AST_STAT_ASSIGN) :: AstStatAssign
    node.vars = vars
    node.values = values
    return node
end
local AST_STAT_COMPOUND_ASSIGN = enum()
export type AstStatCompoundAssign = AstNode & {
    op: number,
    var: AstExpr,
    value: AstExpr
}
local function newAstStatCompoundAssign(op: number, var: AstExpr, value: AstExpr): AstStatCompoundAssign
    expectArg(op, "number", 1)
    expectExpression(var, 2)
    expectExpression(value, 3)
    local node = newStat(AST_STAT_COMPOUND_ASSIGN) :: AstStatCompoundAssign
    node.op = op
    node.var = var
    node.value = value
    return node
end

local AST_STAT_FUNCTION = enum()
export type AstStatFunction = AstNode & {
    name: AstExpr,
    func: AstExprFunction
}
local function newAstStatFunction(name: AstExpr, func: AstExprFunction): AstStatFunction
    expectExpression(name, 1)
    expectExpression(func, 2)
    local node = newStat(AST_STAT_FUNCTION) :: AstStatFunction
    node.name = name
    node.func = func
    return node
end

local AST_STAT_LOCAL_FUNCTION = enum()
export type AstStatLocalFunction = AstNode & {
    name: AstLocal,
    func: AstExprFunction
}
local function newAstStatLocalFunction(name: AstLocal, func: AstExprFunction): AstStatLocalFunction
    expectLocal(name, 1)
    expectExpression(func, 2)
    local node = newStat(AST_STAT_LOCAL_FUNCTION) :: AstStatLocalFunction
    node.name = name
    node.func = func
    return node
end


local AST_STAT_COMMENT = enum()
export type AstStatComment = AstNode & {
    content: string
}
local function newAstStatComment(content: string): AstStatComment
    expectArg(content, "string", 1)
    local node = newStat(AST_STAT_COMMENT) :: AstStatComment
    node.content = content
    return node
end

local AST_STAT_MULTILINE_COMMENT = enum()
export type AstStatMultilineComment = AstNode & {
    content: string
}
local function newAstStatMultilineComment(content: string): AstStatMultilineComment
    expectArg(content, "string", 1)
    local node = newStat(AST_STAT_MULTILINE_COMMENT) :: AstStatMultilineComment
    node.content = content
    return node
end

export type AstStat = AstStatBlock | AstStatIf | AstStatWhile | AstStatRepeat |
    AstStatBreak | AstStatContinue | AstStatReturn | AstStatExpr | AstStatLocal |
    AstStatFor | AstStatForIn | AstStatAssign | AstStatCompoundAssign |
    AstStatFunction | AstStatLocalFunction | AstStatComment | AstStatMultilineComment

local astToString: ( node: AstNode, indent: number? ) -> string

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

local function statArrayToString(array: { AstStat }, indent: number?): string
    local result = ""

    for _, stat in array do
        result ..= ("    "):rep(indent or 0) .. astToString(stat, indent) .. '\n'
    end

    return result:sub(1, -2)
end

local function tableItemToString(item: TableItem, indent: number?): string
    if item.kind == TABLE_ITEM_List then
        return astToString(item.value, indent)
    elseif item.kind == TABLE_ITEM_Record then
        return (item.key::AstExprConstantString).value .. " = " .. astToString(item.value, indent)
    elseif item.kind == TABLE_ITEM_General then
        return '[' .. astToString(item.key, indent) .. '] = ' .. astToString(item.value, indent)
    end
    error("invalid item kind " .. tostring(item.kind))
end
local function tableItemArrayToString(array: { TableItem }, indent: number?): string
    local result = ""

    for _, item in array do
        -- TODO: indent for TableItem s
        result ..= tableItemToString(item, indent) .. ",\n"
    end

    return result:sub(1, -3)
end

local function functionToString(func: AstExprFunction, name: string?, indent: number): string
    local result = ""
    local args = '(' .. localArrayToString(func.args)
    args..= if func.vararg then "...)" else ')'
    result = "function" .. (if name then " " .. name else '') .. args.. '\n'
    indent += 1
    result ..= astToString(func.body, indent) .. '\n'
    indent -= 1
    result ..= ("    "):rep(indent) .. "end"
    return result
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
astToString = function(node: AstNode, indent: number?): string
    local indent = indent or 0

    if node.is_expr then
        if node.t == AST_EXPR_GROUP then
            local expr_group = node :: AstExprGroup
            return '(' .. astToString(expr_group.expr, indent) .. ')'
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
            return astToString(expr_call.func, indent) .. '(' .. args .. ')'
        elseif node.t == AST_EXPR_INDEX_NAME then
            local expr_index_name = node :: AstExprIndexName
            return astToString(expr_index_name.expr, indent) .. '.' .. expr_index_name.index
        elseif node.t == AST_EXPR_INDEX_EXPR then
            local expr_index_expr = node :: AstExprIndexExpr
            return astToString(expr_index_expr.expr, indent) .. '[' .. astToString(expr_index_expr.index, indent) .. ']'
        elseif node.t == AST_EXPR_FUNCTION then
            local expr_function = node :: AstExprFunction
            return functionToString(expr_function, nil, indent)
        elseif node.t == AST_EXPR_TABLE then
            local expr_table = node :: AstExprTable
            return '{' .. tableItemArrayToString(expr_table.items, indent) .. '}'
        elseif node.t == AST_EXPR_UNARY then
            local expr_unary = node :: AstExprUnary
            return UNARY_TOSTRING_MAP[expr_unary.op] ..
                astToString(expr_unary.expr, indent)
        elseif node.t == AST_EXPR_BINARY then
            local expr_binary = node :: AstExprBinary
            return astToString(expr_binary.left, indent) .. ' ' ..
                BINARY_TOSTRING_MAP[expr_binary.op] .. ' ' ..
                astToString(expr_binary.right, indent)
        elseif node.t == AST_EXPR_IF_ELSE then
            local expr_if_else = node :: AstExprIfElse
            return "if " .. astToString(expr_if_else.condition, indent) .. " then " ..
                astToString(expr_if_else.true_expr, indent) .. " else " .. astToString(expr_if_else.false_expr, indent)
        elseif node.t == AST_EXPR_INTERP_STRING then
            local expr_interp_string = node :: AstExprInterpString
            local result = '`'

            local last = 1 
            for i = 1, #expr_interp_string.string_list - 1 do
                last = i + 1
                result ..= formatString(expr_interp_string.string_list[i], true)
                result ..= '{' .. astToString(expr_interp_string.expression_list[i], indent) .. '}'
            end
            result ..= formatString(expr_interp_string.string_list[last], true)

            return result .. '`'

        elseif node.t == AST_EXPR_TOP then
            return "!TOP!"
        end

        error("unknown expression type " .. node.t)
    elseif node.is_stat then
        local result = ""

        local function getIndent()
            return ("    "):rep(indent)
        end

        local function pushIndent() indent += 1 end
        local function popIndent() indent -= 1 end

        local function getEnd()
            return '\n' .. getIndent() .. "end"
        end

        if node.t == AST_STAT_BLOCK then
            local stat_block = node :: AstStatBlock
            result = statArrayToString(stat_block.body, indent)
        elseif node.t == AST_STAT_IF then
            local stat_if = node :: AstStatIf
            result = "if " .. astToString(stat_if.condition, indent) .. " then\n"
            pushIndent()
            result ..= astToString(stat_if.then_body, indent)
            if stat_if.else_body then
                popIndent()
                result ..= "\n" .. getIndent() .. "else\n"
                pushIndent()
                result ..= astToString(stat_if.else_body, indent)
            end
            popIndent()
            result ..= getEnd()
        elseif node.t == AST_STAT_WHILE then
            local stat_while = node :: AstStatWhile
            result = "while " .. astToString(stat_while.condition, indent) .. " do\n"
            pushIndent()
            result ..= astToString(stat_while.body, indent)
            popIndent()
            result ..= getEnd()
        elseif node.t == AST_STAT_REPEAT then
            local stat_repeat = node :: AstStatRepeat
            result = "repeat\n"
            pushIndent()
            result ..= getIndent() .. astToString(stat_repeat.body, indent) .. '\n'
            popIndent()
            result ..= getIndent() .. " until " ..
                astToString(stat_repeat.condition, indent)
        elseif node.t == AST_STAT_BREAK then
            result = "break"
        elseif node.t == AST_STAT_CONTINUE then
            result = "continue"
        elseif node.t == AST_STAT_RETURN then
            local stat_return = node :: AstStatReturn
            result = "return " .. nodeArrayToString(stat_return.list) 
        elseif node.t == AST_STAT_EXPR then
            local expr = (node::AstStatExpr).expr
            result = (if expr.t == AST_EXPR_GROUP then ';' else '') ..
                astToString(expr, indent)
        elseif node.t == AST_STAT_LOCAL then
            local stat_local = node :: AstStatLocal
            result = "local " .. localArrayToString(stat_local.vars) .. " = " ..
                nodeArrayToString(stat_local.values)
        elseif node.t == AST_STAT_FOR then
            local stat_for = node :: AstStatFor
            result = "for " .. localToString(stat_for.var) .. " = " ..
                astToString(stat_for.from, indent) .. ", " .. astToString(stat_for.to, indent) ..
                if stat_for.step then astToString(stat_for.step, indent) else '' ..
                " do\n"
            pushIndent()
            result ..= astToString(stat_for.body, indent)
            popIndent()
            result ..= getEnd()
        elseif node.t == AST_STAT_FOR_IN then
            local stat_for_in = node :: AstStatForIn
            result = "for " .. localArrayToString(stat_for_in.vars) .. " in " ..
                nodeArrayToString(stat_for_in.values) .. " do\n"
            pushIndent()
            result ..= astToString(stat_for_in.body, indent)
            popIndent()
            result ..= getEnd()
        elseif node.t == AST_STAT_ASSIGN then
            local stat_assign = node :: AstStatAssign
            result = nodeArrayToString(stat_assign.vars) .. " = " ..
                nodeArrayToString(stat_assign.values)
        elseif node.t == AST_STAT_COMPOUND_ASSIGN then
            local stat_compound_assign = node :: AstStatCompoundAssign
            result = astToString(stat_compound_assign.var, indent) .. BINARY_TOSTRING_MAP[stat_compound_assign.op] ..
                astToString(stat_compound_assign.value, indent)
        elseif node.t == AST_STAT_FUNCTION then
            local stat_function = node :: AstStatFunction
            result = functionToString(stat_function.func, astToString(stat_function.name, indent), indent)
        elseif node.t == AST_STAT_LOCAL_FUNCTION then
            local stat_local_function = node :: AstStatLocalFunction
            result = "local " .. functionToString(stat_local_function.func, stat_local_function.name.name, indent)

        elseif node.t == AST_STAT_COMMENT then
            local stat_comment = node :: AstStatComment
            result = "--" .. stat_comment.content
        elseif node.t == AST_STAT_MULTILINE_COMMENT then
            local stat_multiline_comment = node :: AstStatMultilineComment
            result = "--[[" .. stat_multiline_comment.content .. "]]"
        else
            error("unknown stat type " .. node.t)
        end

        return result
    end

    error("expected is_expr or is_stat")
end

return {
    TABLE_ITEM_List = TABLE_ITEM_List,
    TABLE_ITEM_Record = TABLE_ITEM_Record,
    TABLE_ITEM_General = TABLE_ITEM_General,

    UNARY_Not = UNARY_Not,
    UNARY_Minus = UNARY_Minus,
    UNARY_Len = UNARY_Len,

    BINARY_Add = BINARY_Add,
    BINARY_Sub = BINARY_Sub,
    BINARY_Mul = BINARY_Mul,
    BINARY_Div = BINARY_Div,
    BINARY_FloorDiv = BINARY_FloorDiv,
    BINARY_Mod = BINARY_Mod,
    BINARY_Pow = BINARY_Pow,
    BINARY_Concat = BINARY_Concat,
    BINARY_CompareNe = BINARY_CompareNe,
    BINARY_CompareEq = BINARY_CompareEq,
    BINARY_CompareLt = BINARY_CompareLt,
    BINARY_CompareLe = BINARY_CompareLe,
    BINARY_CompareGt = BINARY_CompareGt,
    BINARY_CompareGe = BINARY_CompareGe,
    BINARY_And = BINARY_And,
    BINARY_Or = BINARY_Or,

    BINARY_Op__Count = BINARY_Op__Count,

    astToString = astToString,

    AST_EXPR_GROUP = AST_EXPR_GROUP,
    AST_EXPR_CONSTANT_NIL = AST_EXPR_CONSTANT_NIL,
    AST_EXPR_CONSTANT_BOOL = AST_EXPR_CONSTANT_BOOL,
    AST_EXPR_CONSTANT_NUMBER = AST_EXPR_CONSTANT_NUMBER,
    AST_EXPR_CONSTANT_STRING = AST_EXPR_CONSTANT_STRING,
    AST_EXPR_LOCAL = AST_EXPR_LOCAL,
    AST_EXPR_GLOBAL = AST_EXPR_GLOBAL,
    AST_EXPR_VARARGS = AST_EXPR_VARARGS,
    AST_EXPR_CALL = AST_EXPR_CALL,
    AST_EXPR_INDEX_NAME = AST_EXPR_INDEX_NAME,
    AST_EXPR_INDEX_EXPR = AST_EXPR_INDEX_EXPR,
    AST_EXPR_FUNCTION = AST_EXPR_FUNCTION,
    AST_EXPR_TABLE = AST_EXPR_TABLE,
    AST_EXPR_UNARY = AST_EXPR_UNARY,
    AST_EXPR_BINARY = AST_EXPR_BINARY,
    AST_EXPR_IF_ELSE = AST_EXPR_IF_ELSE,
    AST_EXPR_INTERP_STRING = AST_EXPR_INTERP_STRING,

    AST_EXPR_TOP = AST_EXPR_TOP,

    AST_STAT_BLOCK = AST_STAT_BLOCK,
    AST_STAT_IF = AST_STAT_IF,
    AST_STAT_WHILE = AST_STAT_WHILE,
    AST_STAT_REPEAT = AST_STAT_REPEAT,
    AST_STAT_BREAK = AST_STAT_BREAK,
    AST_STAT_CONTINUE = AST_STAT_CONTINUE,
    AST_STAT_RETURN = AST_STAT_RETURN,
    AST_STAT_EXPR = AST_STAT_EXPR,
    AST_STAT_LOCAL = AST_STAT_LOCAL,
    AST_STAT_FOR = AST_STAT_FOR,
    AST_STAT_FOR_IN = AST_STAT_FOR_IN,
    AST_STAT_ASSIGN = AST_STAT_ASSIGN,
    AST_STAT_COMPOUND_ASSIGN = AST_STAT_COMPOUND_ASSIGN,
    AST_STAT_FUNCTION = AST_STAT_FUNCTION,
    AST_STAT_LOCAL_FUNCTION = AST_STAT_LOCAL_FUNCTION,

    AST_STAT_COMMENT = AST_STAT_COMMENT,
    AST_STAT_MULTILINE_COMMENT = AST_STAT_MULTILINE_COMMENT,

    newAstLocal = newAstLocal,

    newAstExprGroup = newAstExprGroup,
    newAstExprConstantNil = newAstExprConstantNil,
    newAstExprConstantBool = newAstExprConstantBool,
    newAstExprConstantNumber = newAstExprConstantNumber,
    newAstExprConstantString = newAstExprConstantString,
    newAstExprLocal = newAstExprLocal,
    newAstExprGlobal = newAstExprGlobal,
    newAstExprVarargs = newAstExprVarargs,
    newAstExprCall = newAstExprCall,
    newAstExprIndexName = newAstExprIndexName,
    newAstExprIndexExpr = newAstExprIndexExpr,
    newAstExprFunction = newAstExprFunction,
    newAstExprTable = newAstExprTable, newTableItem = newTableItem,
    newAstExprUnary = newAstExprUnary,
    newAstExprBinary = newAstExprBinary,
    newAstExprIfElse = newAstExprIfElse,
    newAstExprInterpString = newAstExprInterpString,

    newAstExprTop = newAstExprTop,

    newAstStatBlock = newAstStatBlock,
    newAstStatIf = newAstStatIf,
    newAstStatWhile = newAstStatWhile,
    newAstStatRepeat = newAstStatRepeat,
    newAstStatBreak = newAstStatBreak,
    newAstStatContinue = newAstStatContinue,
    newAstStatReturn = newAstStatReturn,
    newAstStatExpr = newAstStatExpr,
    newAstStatLocal = newAstStatLocal,
    newAstStatFor = newAstStatFor,
    newAstStatForIn = newAstStatForIn,
    newAstStatAssign = newAstStatAssign,
    newAstStatCompoundAssign = newAstStatCompoundAssign,
    newAstStatFunction = newAstStatFunction,
    newAstStatLocalFunction = newAstStatLocalFunction,

    newAstStatComment = newAstStatComment,
    newAstStatMultilineComment = newAstStatMultilineComment
}