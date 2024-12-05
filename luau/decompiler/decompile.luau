--!strict

--[[
    luau/decompiler/decompile.luau
    part of https://github.com/TechHog8984/bitreader.luau
    by techhog
    see LICENSE

    target luau version: 0.635
]]

local log: (...any) -> () = if BITREADER_DEBUG then print else function(...) end

local deserialize = require("../deserialize")
local common = require("../common")
local ast = require("ast")

type Constant = common.Constant

local LBC_CONSTANT_NIL = common.LBC_CONSTANT_NIL
local LBC_CONSTANT_BOOLEAN = common.LBC_CONSTANT_BOOLEAN
local LBC_CONSTANT_NUMBER = common.LBC_CONSTANT_NUMBER
local LBC_CONSTANT_STRING = common.LBC_CONSTANT_STRING
local LBC_CONSTANT_IMPORT = common.LBC_CONSTANT_IMPORT
local LBC_CONSTANT_TABLE = common.LBC_CONSTANT_TABLE
local LBC_CONSTANT_CLOSURE = common.LBC_CONSTANT_CLOSURE
local LBC_CONSTANT_VECTOR = common.LBC_CONSTANT_VECTOR

type ConstantNil = common.ConstantNil
type ConstantBoolean = common.ConstantBoolean
type ConstantNumber = common.ConstantNumber
type ConstantString = common.ConstantString
type ConstantImport = common.ConstantImport
type ConstantTable = common.ConstantTable

type InstructionA = common.InstructionA
type InstructionD = common.InstructionD
type InstructionE  = common.InstructionE

type InstructionAB = common.InstructionAB
type InstructionAC = common.InstructionAC
type InstructionAD = common.InstructionAD

type InstructionAAUX = common.InstructionAAUX
type InstructionABC = common.InstructionABC
type InstructionABAUX = common.InstructionABAUX
type InstructionACAUX = common.InstructionACAUX
type InstructionADAUX = common.InstructionADAUX

type InstructionABCAUX = common.InstructionABCAUX

local tryToGetProto = common.tryToGetProto

local LOP_NOP = common.LOP_NOP

local LOP_BREAK = common.LOP_BREAK

local LOP_LOADNIL = common.LOP_LOADNIL
local LOP_LOADB = common.LOP_LOADB
local LOP_LOADN = common.LOP_LOADN
local LOP_LOADK = common.LOP_LOADK
local LOP_MOVE = common.LOP_MOVE

local LOP_GETGLOBAL = common.LOP_GETGLOBAL
local LOP_SETGLOBAL = common.LOP_SETGLOBAL

local LOP_GETUPVAL = common.LOP_GETUPVAL
local LOP_SETUPVAL = common.LOP_SETUPVAL
local LOP_CLOSEUPVALS = common.LOP_CLOSEUPVALS

local LOP_GETIMPORT = common.LOP_GETIMPORT

local LOP_GETTABLE = common.LOP_GETTABLE
local LOP_SETTABLE = common.LOP_SETTABLE
local LOP_GETTABLEKS = common.LOP_GETTABLEKS
local LOP_SETTABLEKS = common.LOP_SETTABLEKS
local LOP_GETTABLEN = common.LOP_GETTABLEN
local LOP_SETTABLEN = common.LOP_SETTABLEN

local LOP_NEWCLOSURE = common.LOP_NEWCLOSURE
local LOP_NAMECALL = common.LOP_NAMECALL
local LOP_CALL = common.LOP_CALL
local LOP_RETURN = common.LOP_RETURN

local LOP_JUMP = common.LOP_JUMP
local LOP_JUMPBACK = common.LOP_JUMPBACK
local LOP_JUMPIF = common.LOP_JUMPIF
local LOP_JUMPIFNOT = common.LOP_JUMPIFNOT
local LOP_JUMPIFEQ = common.LOP_JUMPIFEQ
local LOP_JUMPIFLE = common.LOP_JUMPIFLE
local LOP_JUMPIFLT = common.LOP_JUMPIFLT
local LOP_JUMPIFNOTEQ = common.LOP_JUMPIFNOTEQ
local LOP_JUMPIFNOTLE = common.LOP_JUMPIFNOTLE
local LOP_JUMPIFNOTLT = common.LOP_JUMPIFNOTLT

local LOP_ADD = common.LOP_ADD
local LOP_SUB = common.LOP_SUB
local LOP_MUL = common.LOP_MUL
local LOP_DIV = common.LOP_DIV
local LOP_MOD = common.LOP_MOD
local LOP_POW = common.LOP_POW

local LOP_ADDK = common.LOP_ADDK
local LOP_SUBK = common.LOP_SUBK
local LOP_MULK = common.LOP_MULK
local LOP_DIVK = common.LOP_DIVK
local LOP_MODK = common.LOP_MODK
local LOP_POWK = common.LOP_POWK

local LOP_AND = common.LOP_AND
local LOP_OR = common.LOP_OR
local LOP_ANDK = common.LOP_ANDK
local LOP_ORK = common.LOP_ORK
local LOP_CONCAT = common.LOP_CONCAT

local LOP_NOT = common.LOP_NOT
local LOP_MINUS = common.LOP_MINUS
local LOP_LENGTH = common.LOP_LENGTH

local LOP_NEWTABLE = common.LOP_NEWTABLE
local LOP_DUPTABLE = common.LOP_DUPTABLE
local LOP_SETLIST = common.LOP_SETLIST

local LOP_FORNPREP = common.LOP_FORNPREP
local LOP_FORNLOOP = common.LOP_FORNLOOP
local LOP_FORGLOOP = common.LOP_FORGLOOP
local LOP_FORGPREP_INEXT = common.LOP_FORGPREP_INEXT

local LOP_FASTCALL3 = common.LOP_FASTCALL3
local LOP_FORGPREP_NEXT = common.LOP_FORGPREP_NEXT

local LOP_NATIVECALL = common.LOP_NATIVECALL

local LOP_GETVARARGS = common.LOP_GETVARARGS

local LOP_DUPCLOSURE = common.LOP_DUPCLOSURE

local LOP_PREPVARARGS = common.LOP_PREPVARARGS

local LOP_LOADKX = common.LOP_LOADKX

local LOP_JUMPX = common.LOP_JUMPX

local LOP_FASTCALL = common.LOP_FASTCALL

local LOP_COVERAGE = common.LOP_COVERAGE

local LOP_CAPTURE = common.LOP_CAPTURE

local LOP_SUBRK = common.LOP_SUBRK
local LOP_DIVRK = common.LOP_DIVRK

local LOP_FASTCALL1 = common.LOP_FASTCALL1
local LOP_FASTCALL2 = common.LOP_FASTCALL2
local LOP_FASTCALL2K = common.LOP_FASTCALL2K

local LOP_FORGPREP = common.LOP_FORGPREP

local LOP_JUMPXEQKNIL = common.LOP_JUMPXEQKNIL
local LOP_JUMPXEQKB = common.LOP_JUMPXEQKB
local LOP_JUMPXEQKN = common.LOP_JUMPXEQKN
local LOP_JUMPXEQKS = common.LOP_JUMPXEQKS

local LOP_IDIV = common.LOP_IDIV
local LOP_IDIVK = common.LOP_IDIVK

local LOP__COUNT = common.LOP__COUNT

local tostringOp = common.tostringOp

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

local AST_EXPR_GROUP = ast.AST_EXPR_GROUP
local AST_EXPR_CONSTANT_NIL = ast.AST_EXPR_CONSTANT_NIL
local AST_EXPR_CONSTANT_BOOL = ast.AST_EXPR_CONSTANT_BOOL
local AST_EXPR_CONSTANT_NUMBER = ast.AST_EXPR_CONSTANT_NUMBER
local AST_EXPR_CONSTANT_STRING = ast.AST_EXPR_CONSTANT_STRING
local AST_EXPR_LOCAL = ast.AST_EXPR_LOCAL
local AST_EXPR_GLOBAL = ast.AST_EXPR_GLOBAL
local AST_EXPR_VARARGS = ast.AST_EXPR_VARARGS
local AST_EXPR_CALL = ast.AST_EXPR_CALL
local AST_EXPR_INDEX_NAME = ast.AST_EXPR_INDEX_NAME
local AST_EXPR_INDEX_EXPR = ast.AST_EXPR_INDEX_EXPR
local AST_EXPR_FUNCTION = ast.AST_EXPR_FUNCTION
local AST_EXPR_TABLE = ast.AST_EXPR_TABLE
local AST_EXPR_UNARY = ast.AST_EXPR_UNARY
local AST_EXPR_BINARY = ast.AST_EXPR_BINARY
local AST_EXPR_IF_ELSE = ast.AST_EXPR_IF_ELSE
local AST_EXPR_INTERP_STRING = ast.AST_EXPR_INTERP_STRING

local AST_STAT_BLOCK = ast.AST_STAT_BLOCK
local AST_STAT_IF = ast.AST_STAT_IF
local AST_STAT_WHILE = ast.AST_STAT_WHILE
local AST_STAT_REPEAT = ast.AST_STAT_REPEAT
local AST_STAT_BREAK = ast.AST_STAT_BREAK
local AST_STAT_CONTINUE = ast.AST_STAT_CONTINUE
local AST_STAT_RETURN = ast.AST_STAT_RETURN
local AST_STAT_EXPR = ast.AST_STAT_EXPR
local AST_STAT_LOCAL = ast.AST_STAT_LOCAL
local AST_STAT_FOR = ast.AST_STAT_FOR
local AST_STAT_FOR_IN = ast.AST_STAT_FOR_IN
local AST_STAT_ASSIGN = ast.AST_STAT_ASSIGN
local AST_STAT_COMPOUND_ASSIGN = ast.AST_STAT_COMPOUND_ASSIGN
local AST_STAT_FUNCTION = ast.AST_STAT_FUNCTION
local AST_STAT_LOCAL_FUNCTION = ast.AST_STAT_LOCAL_FUNCTION
local AST_STAT_COMMENT = ast.AST_STAT_COMMENT
local AST_STAT_MULTILINE_COMMENT = ast.AST_STAT_MULTILINE_COMMENT

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
local newAstStatComment = ast.newAstStatComment
local newAstStatMultilineComment = ast.newAstStatMultilineComment

type Proto = common.Proto

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

local function numberToBool(number: number): boolean
    return if number == 0 then false else true
end

local function tryToCleanIndex(expr_index: AstExprIndexExpr): AstExpr
    local expr = expr_index.index
    if expr.t == AST_EXPR_CONSTANT_STRING then
        local value = (expr::AstExprConstantString).value
        if not value:match("[^%a%d_]") and not value:match("^%d") then
            return newAstExprIndexName(expr_index.expr, value)
        end
    end
    return expr_index
end

type Scope = {
    register_to_local_map: { [number]: AstLocal },
    proto_has_been_created_map: { [number]: boolean },

    expectLocal: ( Scope, number ) -> AstLocal,

    getOrAddLocal: ( Scope, number ) -> (AstLocal, boolean),
    getOrAddLocalAsExpr: ( Scope, number ) -> AstExprLocal,

    addProto: ( Scope, number ) -> string,

    setSingleRegister: ( Scope, number, AstExpr) -> AstStatLocal | AstStatAssign
}

local function decompileProto(proto: Proto): AstStatBlock
    log("proto", proto)

    local proto_list = proto.proto_list
    local constant_list = proto.constant_list

    local instruction_count = proto.size_instructions
    -- create a table of instructions *starting at 1*
    local instruction_list = table.create(instruction_count)
    for i = 0, instruction_count - 1 do
        instruction_list[i + 1] = proto.instructions[i]
    end

    local decompiled_body_count = 0
    local decompiled_body = {}

    local function pushStat(stat: AstStat)
        decompiled_body_count += 1
        decompiled_body[decompiled_body_count] = stat
    end

    local scope: Scope = {
        register_to_local_map = {},
        proto_has_been_created_map = {},

        expectLocal = function(self: Scope, register: number): AstLocal
            return assert(self.register_to_local_map[register], "failed to find register " .. register .. " in map")
        end,

        getOrAddLocal = function(self: Scope, register: number): (AstLocal, boolean)
            local is_new = not self.register_to_local_map[register]
            if is_new then
                self.register_to_local_map[register] = newAstLocal("var" .. register)
            end
            return self.register_to_local_map[register], is_new
        end,
        getOrAddLocalAsExpr = function(self: Scope, register: number): AstExprLocal
            return newAstExprLocal(
                (self:getOrAddLocal(register))
            )
        end,

        addProto = function(self: Scope, proto_id: number): string
            local child_proto = proto_list[proto_id]
            local name = "func" .. child_proto.bytecode_id
            if self.proto_has_been_created_map[proto_id] then
                return name
            end

            local args: { AstLocal } = {}
            for i = 1, child_proto.num_params do
                args[i] = newAstLocal("arg" .. i)
            end

            pushStat(newAstStatLocalFunction(
                newAstLocal(name),
                newAstExprFunction(
                    args,
                    child_proto.is_vararg,
                    decompileProto(child_proto)
                )
            ))
            self.proto_has_been_created_map[proto_id] = true

            return name
        end,

        setSingleRegister = function(self: Scope, register: number, expr: AstExpr): AstStatLocal | AstStatAssign
            local ast_local, is_new = self:getOrAddLocal(register)
            return if is_new then newAstStatLocal(
                { ast_local },
                { expr }
            ) else newAstStatAssign(
                { newAstExprLocal(ast_local) },
                { expr }
            )
        end
    }

    local function getConstantExpr(constant: Constant): AstExpr
        if constant.t == LBC_CONSTANT_NIL then
            return newAstExprConstantNil()
        elseif constant.t == LBC_CONSTANT_BOOLEAN then
            return newAstExprConstantBool((constant::ConstantBoolean).bool)
        elseif constant.t == LBC_CONSTANT_NUMBER then
            return newAstExprConstantNumber((constant::ConstantNumber).number)
        elseif constant.t == LBC_CONSTANT_STRING then
            return newAstExprConstantString((constant::ConstantString).string)
        elseif constant.t == LBC_CONSTANT_IMPORT then
            return newAstStatMultilineComment("unhandled constant type import")
        elseif constant.t == LBC_CONSTANT_TABLE then
            return newAstStatMultilineComment("unhandled constant type table")
        elseif constant.t == LBC_CONSTANT_CLOSURE then
            return newAstStatMultilineComment("unhandled constant type closure")
        elseif constant.t == LBC_CONSTANT_VECTOR then
            return newAstStatMultilineComment("unhandled constant type vector")
        else
            return newAstStatMultilineComment("INVALID CONSTANT TYPE " .. tostring(constant.t))
        end
    end

    local function step1()
        for index = 1, instruction_count do
            local instruction = instruction_list[index]
            local op = instruction.op

            if op == LOP_NOP then
                pushStat(newAstStatComment(" noop"))
            elseif op == LOP_BREAK then
                pushStat(newAstStatComment(" debuger break"))

            elseif op == LOP_LOADNIL then
                local instructiona = instruction :: InstructionA
                pushStat(scope:setSingleRegister(
                    instructiona.a, newAstExprConstantNil()
                ))
            elseif op == LOP_LOADB then
                local instructionabc = instruction :: InstructionABC
                pushStat(scope:setSingleRegister(
                    instructionabc.a,
                    newAstExprConstantBool(numberToBool(instructionabc.b))
                ))
            elseif op == LOP_LOADN then
                local instructionad = instruction :: InstructionAD
                pushStat(scope:setSingleRegister(
                    instructionad.a,
                    newAstExprConstantNumber(instructionad.d)
                ))
            elseif op == LOP_LOADK then
                local instructionad = instruction :: InstructionAD
                pushStat(scope:setSingleRegister(
                    instructionad.a,
                    getConstantExpr(constant_list[instructionad.d])
                ))

            elseif op == LOP_MOVE then
                local instructionab = instruction :: InstructionAB
                pushStat(scope:setSingleRegister(
                    instructionab.a,
                    newAstExprLocal(scope:expectLocal(instructionab.b))
                ))

            elseif op == LOP_GETGLOBAL then
                local instructionacaux = instruction :: InstructionACAUX
                local constant = constant_list[instructionacaux.aux] :: ConstantString
                pushStat(scope:setSingleRegister(
                    instructionacaux.a,
                    newAstExprGlobal(constant.string)
                ))
            elseif op == LOP_SETGLOBAL then
                local instructionacaux = instruction :: InstructionACAUX
                local constant = constant_list[instructionacaux.aux] :: ConstantString
                pushStat(newAstStatAssign(
                    { newAstExprGlobal(constant.string) },
                    { scope:getOrAddLocalAsExpr(instructionacaux.a)}
                ))
            -- upval stuff here

            elseif op == LOP_GETIMPORT then
                local instructionadaux = instruction :: InstructionADAUX
                local constant = constant_list[instructionadaux.d] :: ConstantImport
                pushStat(scope:setSingleRegister(
                    instructionadaux.a,
                    newAstExprGlobal(constant.import)
                ))

            elseif op == LOP_GETTABLE then
                local instructionabc = instruction :: InstructionABC
                pushStat(scope:setSingleRegister(
                    instructionabc.a,
                    newAstExprIndexExpr(
                        scope:getOrAddLocalAsExpr(instructionabc.b),
                        scope:getOrAddLocalAsExpr(instructionabc.c)
                    )
                ))
            elseif op == LOP_SETTABLE then
                local instructionabc = instruction :: InstructionABC
                pushStat(newAstStatAssign(
                    { newAstExprIndexExpr(
                        scope:getOrAddLocalAsExpr(instructionabc.b),
                        scope:getOrAddLocalAsExpr(instructionabc.c)
                    ) },
                    { scope:getOrAddLocalAsExpr(instructionabc.a) }
                ))
            elseif op == LOP_GETTABLEKS then
                local instructionabcaux = instruction :: InstructionABCAUX
                pushStat(scope:setSingleRegister(
                    instructionabcaux.a,
                    tryToCleanIndex(newAstExprIndexExpr(
                        scope:getOrAddLocalAsExpr(instructionabcaux.b),
                            getConstantExpr(constant_list[instructionabcaux.aux])
                    ))
                ))
            elseif op == LOP_SETTABLEKS then
                local instructionabcaux = instruction::InstructionABCAUX
                pushStat(newAstStatAssign(
                    { newAstExprIndexExpr(
                        scope:getOrAddLocalAsExpr(instructionabcaux.b),
                        getConstantExpr(constant_list[instructionabcaux.aux])
                    ) },
                    { scope:getOrAddLocalAsExpr(instructionabcaux.a) }
                ))
            elseif op == LOP_GETTABLEN then
                local instructionabc = instruction :: InstructionABC
                pushStat(scope:setSingleRegister(
                    instructionabc.a,
                    newAstExprIndexExpr(
                        scope:getOrAddLocalAsExpr(instructionabc.b),
                        newAstExprConstantNumber(instructionabc.c + 1)
                    )
                ))
            elseif op == LOP_SETTABLEN then
                local instructionabc = instruction :: InstructionABC
                pushStat(newAstStatAssign(
                    { newAstExprIndexExpr(
                        scope:getOrAddLocalAsExpr(instructionabc.b),
                        newAstExprConstantNumber(instructionabc.c + 1)
                    ) },
                    { scope:getOrAddLocalAsExpr(instructionabc.a) }
                ))
            elseif op == LOP_NEWCLOSURE then
                local instructionad = instruction :: InstructionAD
                local name = scope:addProto(instructionad.d)
                pushStat(scope:setSingleRegister(instructionad.a, newAstExprLocal(newAstLocal(name))))
            else
                pushStat(newAstStatComment("unhandled op " .. tostringOp(op)))
            end
        end
    end

    step1()

    -- testing
    -- pushStat(
    --     newAstStatFunction(newAstExprLocal(newAstLocal("hi")), newAstExprFunction(
    --         {},
    --         true,
    --         newAstStatBlock({
    --             newAstStatLocalFunction(newAstLocal("inner"), newAstExprFunction(
    --                 { newAstLocal("arg1") },
    --                 false,
    --                 newAstStatBlock({})
    --             )),
    --             newAstStatReturn({})
    --         })
    --     ))
    -- )

    return newAstStatBlock(decompiled_body)
end
local function decompile(arg1: string | buffer | Proto): string
    local proto = tryToGetProto(arg1, deserialize)
    local ast_stat = decompileProto(proto)

    return astToString(ast_stat)
end

return decompile