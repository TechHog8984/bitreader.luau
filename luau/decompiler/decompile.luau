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

local fold = require("fold")

type Constant = common.Constant

type ConstantNil = common.ConstantNil
type ConstantBoolean = common.ConstantBoolean
type ConstantNumber = common.ConstantNumber
type ConstantString = common.ConstantString
type ConstantImport = common.ConstantImport
type ConstantTable = common.ConstantTable
type ConstantClosure = common.ConstantClosure

type Instruction = common.Instruction

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
local tostringOp = common.tostringOp

local astToString = ast.astToString

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
    if expr.t == ast.AST_EXPR_CONSTANT_STRING then
        local value = (expr::AstExprConstantString).value
        if not value:match("[^%a%d_]") and not value:match("^%d") then
            return ast.newAstExprIndexName(expr_index.expr, value)
        end
    end
    return expr_index
end

type Scope = {
    register_to_local_map: { [number]: AstLocal },
    proto_has_been_created_map: { [number]: boolean },

    expectLocal: ( Scope, number ) -> AstLocal,
    expectLocalAsExpr: ( Scope, number ) -> AstExprLocal,

    getOrAddLocal: ( Scope, number ) -> (AstLocal, boolean),
    getOrAddLocalAsExpr: ( Scope, number ) -> AstExprLocal,

    addProto: ( Scope, number ) -> string,

    setSingleRegister: ( Scope, number, AstExpr) -> AstStatLocal | AstStatAssign
}

local BINARY_LOP_TO_OP_MAP: { [number]: number } = {
    [common.LOP_ADD] = ast.BINARY_Add,
    [common.LOP_SUB] = ast.BINARY_Sub,
    [common.LOP_MUL] = ast.BINARY_Mul,
    [common.LOP_DIV] = ast.BINARY_Div,
    [common.LOP_IDIV] = ast.BINARY_FloorDiv,
    [common.LOP_MOD] = ast.BINARY_Mod,
    [common.LOP_POW] = ast.BINARY_Pow,

    [common.LOP_CONCAT] = ast.BINARY_Concat,

    [common.LOP_AND] = ast.BINARY_And,
    [common.LOP_OR] = ast.BINARY_Or,

    [common.LOP_ADDK] = ast.BINARY_Add,
    [common.LOP_SUBK] = ast.BINARY_Sub,
    [common.LOP_MULK] = ast.BINARY_Mul,
    [common.LOP_DIVK] = ast.BINARY_Div,
    [common.LOP_IDIVK] = ast.BINARY_FloorDiv,
    [common.LOP_MODK] = ast.BINARY_Mod,
    [common.LOP_POWK] = ast.BINARY_Pow,

    [common.LOP_ANDK] = ast.BINARY_And,
    [common.LOP_ORK] = ast.BINARY_Or,
}
local UNARY_OP_TO_OP_MAP: { [number]: number } = {
    [common.LOP_NOT] = ast.UNARY_Not,
    [common.LOP_MINUS] = ast.UNARY_Minus,
    [common.LOP_LENGTH] = ast.UNARY_Len,
}

local function decompileProto(proto: Proto): AstStatBlock
    log("proto", proto)

    local proto_list = proto.proto_list
    local constant_list = proto.constant_list

    local instruction_count = proto.size_instructions
    local instruction_count_plus1 = instruction_count + 1
    -- create a table of instructions *starting at 1*
    -- this table may be modified on-demand (see step1's LOP_NAMECALL)
    local instruction_list = table.create(instruction_count)
    for i = 0, instruction_count - 1 do
        instruction_list[i + 1] = proto.instructions[i]
    end
    
    local function insertInstruction(index: number, instruction: Instruction)
        table.insert(instruction_list, index, instruction)
        instruction_count += 1
        instruction_count_plus1 += 1
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
        expectLocalAsExpr = function(self: Scope, register: number): AstExprLocal
            return ast.newAstExprLocal(self:expectLocal(register))
        end,

        getOrAddLocal = function(self: Scope, register: number): (AstLocal, boolean)
            local is_new = not self.register_to_local_map[register]
            if is_new then
                self.register_to_local_map[register] = ast.newAstLocal("var" .. register)
            end
            return self.register_to_local_map[register], is_new
        end,
        getOrAddLocalAsExpr = function(self: Scope, register: number): AstExprLocal
            return ast.newAstExprLocal(
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
                args[i] = ast.newAstLocal("arg" .. i)
            end

            pushStat(ast.newAstStatLocalFunction(
                ast.newAstLocal(name),
                ast.newAstExprFunction(
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
            return if is_new then ast.newAstStatLocal(
                { ast_local },
                { expr }
            ) else ast.newAstStatAssign(
                { ast.newAstExprLocal(ast_local) },
                { expr }
            )
        end
    }

    local function getConstantExpr(constant: Constant): AstExpr
        if constant.t == common.LBC_CONSTANT_NIL then
            return ast.newAstExprConstantNil()
        elseif constant.t == common.LBC_CONSTANT_BOOLEAN then
            return ast.newAstExprConstantBool((constant::ConstantBoolean).bool)
        elseif constant.t == common.LBC_CONSTANT_NUMBER then
            return ast.newAstExprConstantNumber((constant::ConstantNumber).number)
        elseif constant.t == common.LBC_CONSTANT_STRING then
            return ast.newAstExprConstantString((constant::ConstantString).string)
        elseif constant.t == common.LBC_CONSTANT_IMPORT then
            return ast.newAstStatMultilineComment("unhandled constant type import")
        elseif constant.t == common.LBC_CONSTANT_TABLE then
            return ast.newAstStatMultilineComment("unhandled constant type table")
        elseif constant.t == common.LBC_CONSTANT_CLOSURE then
            return ast.newAstStatMultilineComment("unhandled constant type closure")
        elseif constant.t == common.LBC_CONSTANT_VECTOR then
            return ast.newAstStatMultilineComment("unhandled constant type vector")
        else
            return ast.newAstStatMultilineComment("INVALID CONSTANT TYPE " .. tostring(constant.t))
        end
    end

    local function step1()
        local index = 1
        while true do
            if index == instruction_count_plus1 then
                break
            end
            local instruction = instruction_list[index]
            local op = instruction.op

            if op == common.LOP_NOP then
                pushStat(ast.newAstStatComment(" noop"))
            elseif op == common.LOP_BREAK then
                pushStat(ast.newAstStatComment(" debuger break"))

            elseif op == common.LOP_LOADNIL then
                local instructiona = instruction :: InstructionA
                pushStat(scope:setSingleRegister(
                    instructiona.a, ast.newAstExprConstantNil()
                ))
            elseif op == common.LOP_LOADB then
                local instructionabc = instruction :: InstructionABC
                pushStat(scope:setSingleRegister(
                    instructionabc.a,
                    ast.newAstExprConstantBool(numberToBool(instructionabc.b))
                ))
            elseif op == common.LOP_LOADN then
                local instructionad = instruction :: InstructionAD
                pushStat(scope:setSingleRegister(
                    instructionad.a,
                    ast.newAstExprConstantNumber(instructionad.d)
                ))
            elseif op == common.LOP_LOADK then
                local instructionad = instruction :: InstructionAD
                pushStat(scope:setSingleRegister(
                    instructionad.a,
                    getConstantExpr(constant_list[instructionad.d])
                ))

            elseif op == common.LOP_MOVE then
                local instructionab = instruction :: InstructionAB
                pushStat(scope:setSingleRegister(
                    instructionab.a,
                    scope:expectLocalAsExpr(instructionab.b)
                ))

            elseif op == common.LOP_GETGLOBAL then
                local instructionacaux = instruction :: InstructionACAUX
                local constant = constant_list[instructionacaux.aux] :: ConstantString
                pushStat(scope:setSingleRegister(
                    instructionacaux.a,
                    ast.newAstExprGlobal(constant.string)
                ))
            elseif op == common.LOP_SETGLOBAL then
                local instructionacaux = instruction :: InstructionACAUX
                local constant = constant_list[instructionacaux.aux] :: ConstantString
                pushStat(ast.newAstStatAssign(
                    { ast.newAstExprGlobal(constant.string) },
                    { scope:expectLocalAsExpr(instructionacaux.a)}
                ))

            -- TODO: upval ops

            elseif op == common.LOP_GETIMPORT then
                local instructionadaux = instruction :: InstructionADAUX
                local constant = constant_list[instructionadaux.d] :: ConstantImport
                pushStat(scope:setSingleRegister(
                    instructionadaux.a,
                    ast.newAstExprGlobal(constant.import)
                ))

            elseif op == common.LOP_GETTABLE then
                local instructionabc = instruction :: InstructionABC
                pushStat(scope:setSingleRegister(
                    instructionabc.a,
                    ast.newAstExprIndexExpr(
                        scope:expectLocalAsExpr(instructionabc.b),
                        scope:expectLocalAsExpr(instructionabc.c)
                    )
                ))
            elseif op == common.LOP_SETTABLE then
                local instructionabc = instruction :: InstructionABC
                pushStat(ast.newAstStatAssign(
                    { ast.newAstExprIndexExpr(
                        scope:expectLocalAsExpr(instructionabc.b),
                        scope:expectLocalAsExpr(instructionabc.c)
                    ) },
                    { scope:expectLocalAsExpr(instructionabc.a) }
                ))
            elseif op == common.LOP_GETTABLEKS then
                local instructionabcaux = instruction :: InstructionABCAUX
                pushStat(scope:setSingleRegister(
                    instructionabcaux.a,
                    tryToCleanIndex(ast.newAstExprIndexExpr(
                        scope:expectLocalAsExpr(instructionabcaux.b),
                            getConstantExpr(constant_list[instructionabcaux.aux])
                    ))
                ))
            elseif op == common.LOP_SETTABLEKS then
                local instructionabcaux = instruction::InstructionABCAUX
                pushStat(ast.newAstStatAssign(
                    { ast.newAstExprIndexExpr(
                        scope:expectLocalAsExpr(instructionabcaux.b),
                        getConstantExpr(constant_list[instructionabcaux.aux])
                    ) },
                    { scope:expectLocalAsExpr(instructionabcaux.a) }
                ))
            elseif op == common.LOP_GETTABLEN then
                local instructionabc = instruction :: InstructionABC
                pushStat(scope:setSingleRegister(
                    instructionabc.a,
                    ast.newAstExprIndexExpr(
                        scope:expectLocalAsExpr(instructionabc.b),
                        ast.newAstExprConstantNumber(instructionabc.c + 1)
                    )
                ))
            elseif op == common.LOP_SETTABLEN then
                local instructionabc = instruction :: InstructionABC
                pushStat(ast.newAstStatAssign(
                    { ast.newAstExprIndexExpr(
                        scope:expectLocalAsExpr(instructionabc.b),
                        ast.newAstExprConstantNumber(instructionabc.c + 1)
                    ) },
                    { scope:expectLocalAsExpr(instructionabc.a) }
                ))

            elseif op == common.LOP_NEWCLOSURE then
                local instructionad = instruction :: InstructionAD
                local name = scope:addProto(instructionad.d)
                pushStat(scope:setSingleRegister(instructionad.a,
                    ast.newAstExprLocal(ast.newAstLocal(name))
                ))

            elseif op == common.LOP_NAMECALL then
                local instructionabcaux = instruction :: InstructionABCAUX
                -- a+1 = b
                insertInstruction(index + 1, {
                    op = common.LOP_MOVE,
                    a = instructionabcaux.a + 1,
                    b = instructionabcaux.b
                } :: InstructionAB)
                -- a = value
                insertInstruction(index + 2, {
                    op = common.LOP_GETTABLEKS,
                    a = instructionabcaux.a,
                    b = instructionabcaux.a + 1,
                    c = instructionabcaux.c,
                    aux = instructionabcaux.aux
                } :: InstructionABCAUX)
            elseif op == common.LOP_CALL then
                local instructionabc = instruction :: InstructionABC
                local func = instructionabc.a
                local arg_count = instructionabc.b - 1
                local result_count = instructionabc.c - 1

                local args: { AstExpr } = {}
                local results: { AstLocal } = {}

                if arg_count == -1 then
                    args[1] = ast.newAstExprTop()
                else
                    for i = 1, arg_count do
                        args[i] = scope:expectLocalAsExpr(func + i)
                    end
                end

                if result_count == -1 then
                    results[1] = ast.newAstLocal("!TOP!")
                else
                    for i = 1, result_count do
                        local ast_local, is_new = scope:getOrAddLocal(func + i - 1)
                        results[i] = ast_local
                        -- TODO: look into cases where this is valid
                        if not is_new then
                            assert("call result " .. i .. " (register " .. func + i - 1 .. ") was not new")
                        end
                    end
                end

                local call_expr = ast.newAstExprCall(
                    scope:expectLocalAsExpr(instructionabc.a),
                    args,
                    false
                )
                pushStat(
                    if next(results) then
                        -- TODO: look into cases where this is an AstStatAssign
                        ast.newAstStatLocal(results, { call_expr })
                    else
                        ast.newAstStatExpr(call_expr)
                )

            elseif op == common.LOP_RETURN then
                local instructionab = instruction :: InstructionAB
                local start = instructionab.a

                local list: { AstExpr } = {}

                local count = instructionab.b - 1
                if count == -1 then
                    list[1] = ast.newAstExprTop()
                else
                    for i = 1, count do
                        list[i] = scope:expectLocalAsExpr(start + i - 1)
                    end
                end

                pushStat(ast.newAstStatReturn(list))

            -- TODO: jumps
            -- elseif op == LOP_JUMP then

            -- elseif op == LOP_JUMPBACK then

            -- elseif op == LOP_JUMPIF then

            -- elseif op == LOP_JUMPIFNOT then

            -- elseif op == LOP_JUMPIFEQ then
            -- elseif op == LOP_JUMPIFLE then
            -- elseif op == LOP_JUMPIFLT then
            -- elseif op == LOP_JUMPIFNOTEQ then
            -- elseif op == LOP_JUMPIFNOTLE then
            -- elseif op == LOP_JUMPIFNOTLT then

            elseif op == common.LOP_ADD or
                op == common.LOP_SUB or
                op == common.LOP_MUL or
                op == common.LOP_DIV or
                op == common.LOP_IDIV or
                op == common.LOP_MOD or
                op == common.LOP_POW
            then
                local instructionabc = instruction :: InstructionABC
                pushStat(scope:setSingleRegister(
                    instructionabc.a,
                    ast.newAstExprBinary(BINARY_LOP_TO_OP_MAP[op],
                        scope:expectLocalAsExpr(instructionabc.b),
                        scope:expectLocalAsExpr(instructionabc.c)
                    )
                ))

            elseif op == common.LOP_CONCAT then
                local instructionabc = instruction :: InstructionABC
                local register_start = instructionabc.b
                local register_end = instructionabc.c

                local expr: AstExpr = scope:expectLocalAsExpr(register_start)
                for i = register_start + 1, register_end do
                    expr = ast.newAstExprBinary(ast.BINARY_Concat,
                        expr,
                        scope:expectLocalAsExpr(i)
                    )
                end

                pushStat(scope:setSingleRegister(
                    instructionabc.a,
                    expr
                ))

            elseif op == common.LOP_ADDK or
                op == common.LOP_SUBK or
                op == common.LOP_MULK or
                op == common.LOP_DIVK or
                op == common.LOP_IDIVK or
                op == common.LOP_MODK or
                op == common.LOP_POWK
            then
                local instructionabc = instruction :: InstructionABC
                pushStat(scope:setSingleRegister(
                    instructionabc.a,
                    ast.newAstExprBinary(BINARY_LOP_TO_OP_MAP[op],
                        scope:expectLocalAsExpr(instructionabc.b),
                        getConstantExpr(constant_list[instructionabc.c])
                    )
                ))

            elseif op == common.LOP_NOT or
                op == common.LOP_MINUS or
                op == common.LOP_LENGTH
            then
                local instructionab = instruction :: InstructionAB
                pushStat(scope:setSingleRegister(
                    instructionab.a,
                    ast.newAstExprUnary(UNARY_OP_TO_OP_MAP[op],
                        scope:expectLocalAsExpr(instructionab.b)
                    )
                ))

            elseif op == common.LOP_NEWTABLE then
                local instructionabaux = instruction :: InstructionABAUX
                pushStat(scope:setSingleRegister(instructionabaux.a,
                    ast.newAstExprTable({})
                ))
            elseif op == common.LOP_DUPTABLE then
                local instructionad = instruction :: InstructionAD
                pushStat(scope:setSingleRegister(instructionad.a,
                    ast.newAstExprTable({})
                ))
            elseif op == common.LOP_SETLIST then
                local instructionabcaux = instruction :: InstructionABCAUX
                local target = instructionabcaux.a
                local start = instructionabcaux.b
                local count = instructionabcaux.c - 1
                local aux = instructionabcaux.aux

                if count == -1 then
                    pushStat(ast.newAstStatAssign(
                        { ast.newAstExprIndexExpr(
                            scope:expectLocalAsExpr(target),
                            ast.newAstExprUnknown()
                        ) },
                        { ast.newAstExprTop() }
                    ))
                else
                    for i = 1, count do
                        pushStat(ast.newAstStatAssign(
                            { ast.newAstExprIndexExpr(
                                scope:expectLocalAsExpr(target),
                                ast.newAstExprConstantNumber(i + aux - 1)
                            ) },
                            { scope:expectLocalAsExpr(start + i - 1) }
                        ))
                    end
                end

            -- TODO: for loops
            -- elseif op == common.LOP_FORNPREP then
            -- elseif op == common.LOP_FORNLOOP then

            -- elseif op == common.LOP_FORGLOOP then

            -- elseif op == common.LOP_FORGPREP_INEXT then

            -- elseif op == common.LOP_FORGPREP_NEXT then

            -- TODO: fastcall3

            elseif op == common.LOP_GETVARARGS then
                local instructionab = instruction :: InstructionAB
                local target = instructionab.a
                local count = instructionab.b - 1

                local results: { AstLocal } = {}

                if count == -1 then
                    pushStat(ast.newAstStatAssign(
                        { ast.newAstExprTop() },
                        { ast.newAstExprVarargs() }
                    ))
                else
                    local all_new = true
                    local last_is_new: boolean | number = 0
                    assert(count > 0)
                    for i = 1, count do
                        local ast_local, is_new = scope:getOrAddLocal(target + i - 1)
                        results[i] = ast_local

                        if last_is_new == 0 then
                            last_is_new = is_new
                        else
                            if is_new ~= last_is_new then
                                error("is_new mismatch in GETVARARGS")
                            end
                        end

                        if not is_new then
                            all_new = false
                        end
                    end

                    if all_new then
                        pushStat(ast.newAstStatLocal(results,
                            { ast.newAstExprVarargs() }
                        ))
                    else
                        local expressions: { AstExpr } = {}
                        for i = 1, count do
                            expressions[i] = ast.newAstExprLocal(results[i])
                        end
                        pushStat(ast.newAstStatAssign(
                            expressions,
                            { ast.newAstExprVarargs() }
                        ))
                    end
                end

            elseif op == common.LOP_DUPCLOSURE then
                local instructionad = instruction :: InstructionAD
                local constant = constant_list[instructionad.d] :: ConstantClosure
                local name = scope:addProto(constant.closure.proto.bytecode_id)
                pushStat(scope:setSingleRegister(instructionad.a,
                    ast.newAstExprLocal(ast.newAstLocal(name))
                ))

            elseif op == common.LOP_PREPVARARGS then
                pushStat(ast.newAstStatComment(" prep varargs"))

            elseif op == common.LOP_LOADKX then
                local instructionaaux = instruction :: InstructionAAUX
                pushStat(scope:setSingleRegister(
                    instructionaaux.a,
                    getConstantExpr(constant_list[instructionaaux.aux])
                ))

            -- TODO: jumpx
            else
                pushStat(ast.newAstStatComment("unhandled op " .. tostringOp(op)))
            end
            index += 1
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

    local result_block = ast.newAstStatBlock(decompiled_body)
    fold(result_block)
    return result_block
end
local function decompile(arg1: string | buffer | Proto): string
    local proto = tryToGetProto(arg1, deserialize)
    local ast_stat = decompileProto(proto)

    return astToString(ast_stat)
end

return decompile