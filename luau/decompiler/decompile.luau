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

-- local fold = require("fold")

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
            return ast.newAstExprIndexName(expr_index.expr, value, '.')
        end
    end
    return expr_index
end

local function getExpressionListFromAstLocalList(ast_local_list: { AstLocal }): { AstExpr }
    local expressions: { AstExpr } = {}
    for i = 1, #ast_local_list do
        expressions[i] = ast.newAstExprLocal(ast_local_list[i])
    end
    return expressions
end

type VariablePrefix = "var" | "arg" | "upval"
type Variable = {
    prefix: VariablePrefix,
    register: number,

    ast_local: AstLocal,
}

local function newVariable(prefix: VariablePrefix, register: number): Variable
    return {
        prefix = prefix,
        register = register,
        ast_local = ast.newAstLocal(prefix .. register)
    }
end
local function newVariableVar(register: number): Variable
    return newVariable("var", register)
end
local function newVariableArg(arg: number): Variable
    return newVariable("arg", arg)
end
local function newVariableUpval(upvalue: number): Variable
    return newVariable("upval", upvalue)
end

type Scope = {
    register_to_variable_map: { [number]: Variable },
    proto_has_been_created_map: { [number]: boolean },

    expectRegister: ( Scope, number ) -> Variable,
    expectRegisterAsExpr: ( Scope, number ) -> AstExprLocal,

    getOrAddRegister: ( Scope, number ) -> (Variable, boolean),
    getOrAddRegisterAsExpr: ( Scope, number ) -> AstExprLocal,

    addProto: ( Scope, number ) -> string,

    setSingleRegister: ( Scope, number, AstExpr) -> AstStatLocal | AstStatAssign,
    setRegisterListSingleExpr: (Scope, number, number, AstExpr) -> AstStatLocal
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

    [common.LOP_SUBRK] = ast.BINARY_Sub,
    [common.LOP_DIVRK] = ast.BINARY_Div,
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
    local instruction_list = proto.instructions

    local decompiled_body_count = 0
    local decompiled_body = {}

    local function pushStat(stat: AstStat)
        decompiled_body_count += 1
        decompiled_body[decompiled_body_count] = stat
    end
    -- FIXME: this is untested
    -- local function pushStatList(stat_list: { AstStat })
    --     local count = #stat_list
    --     table.move(stat_list, 1, count, decompiled_body_count + 1, decompiled_body)
    --     decompiled_body_count += count
    -- end

    local state: {
        current_instruction: Instruction,
        current_index: number | string,
        current_op: number
    }

    local function betterError(message: string): never
        error(message .. "\nstate: [\n  proto id = " .. proto.bytecode_id
            .. "\n  instruction index = " .. state.current_index .. " -- starting at zero"
            .. "\n  instruction = " .. state.current_instruction:format() .. "\n]", 2)
    end
    local function betterAssert<T>(value: T, message: string): T
        if value then
            return value
        end
        return betterError(message)
    end

    local scope: Scope = {
        register_to_variable_map = {},
        proto_has_been_created_map = {},

        expectRegister = function(self: Scope, register: number): Variable
            return betterAssert(self.register_to_variable_map[register], "failed to find register " .. register .. " in map")
        end,
        expectRegisterAsExpr = function(self: Scope, register: number): AstExprLocal
            return ast.newAstExprLocal(self:expectRegister(register).ast_local)
        end,

        getOrAddRegister = function(self: Scope, register: number): (Variable, boolean)
            local is_new = not self.register_to_variable_map[register]
            if is_new then
                self.register_to_variable_map[register] = newVariableVar(register);
            end
            return self.register_to_variable_map[register], is_new
        end,
        getOrAddRegisterAsExpr = function(self: Scope, register: number): AstExprLocal
            return ast.newAstExprLocal(
                (self:getOrAddRegister(register)).ast_local
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
                args[i] = ast.newAstLocal("arg" .. i - 1)
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
            local variable, is_new = self:getOrAddRegister(register)
            return if is_new then ast.newAstStatLocal(
                { variable.ast_local },
                { expr }
            ) else ast.newAstStatAssign(
                { ast.newAstExprLocal(variable.ast_local) },
                { expr }
            )
        end,
        setRegisterListSingleExpr = function(self: Scope, register_start: number, register_end: number, expr: AstExpr): AstStatLocal
            local vars: { AstLocal } = {} 
            for i = register_start, register_end do
                local index = #vars + 1
                vars[index] = self:getOrAddRegister(i).ast_local
            end

            return ast.newAstStatLocal(vars, { expr })
        end
    }

    for i = 1, proto.num_params do
        i -= 1
        scope.register_to_variable_map[i] = newVariableArg(i)
    end

    local function getConstantExpr(constant: Constant?): AstExpr
        if not constant then
            return ast.newAstExprMultilineComment("nil constant")
        end

        if constant.t == common.LBC_CONSTANT_NIL then
            return ast.newAstExprConstantNil()
        elseif constant.t == common.LBC_CONSTANT_BOOLEAN then
            return ast.newAstExprConstantBool((constant::ConstantBoolean).bool)
        elseif constant.t == common.LBC_CONSTANT_NUMBER then
            return ast.newAstExprConstantNumber((constant::ConstantNumber).number)
        elseif constant.t == common.LBC_CONSTANT_STRING then
            return ast.newAstExprConstantString((constant::ConstantString).string)
        elseif constant.t == common.LBC_CONSTANT_IMPORT then
            return ast.newAstExprMultilineComment("unhandled constant type import")
        elseif constant.t == common.LBC_CONSTANT_TABLE then
            return ast.newAstExprMultilineComment("unhandled constant type table")
        elseif constant.t == common.LBC_CONSTANT_CLOSURE then
            return ast.newAstExprMultilineComment("unhandled constant type closure")
        elseif constant.t == common.LBC_CONSTANT_VECTOR then
            return ast.newAstExprMultilineComment("unhandled constant type vector")
        else
            return ast.newAstExprMultilineComment("INVALID CONSTANT TYPE " .. tostring(constant.t))
        end
    end
    local function getUpvalueExpr(upvalue: number): AstExpr
        if not upvalue then
            return ast.newAstExprMultilineComment("nil upvalue")
        end

        return ast.newAstExprLocal(newVariableUpval(upvalue).ast_local)
    end

    local function step1()
        local index = 0
        state = {
            current_instruction = instruction_list[index],
            current_index = index,
            current_op = instruction_list[index].op
        }

        local namecall_holder: InstructionABCAUX? = nil
        while true do
            if index == instruction_count then
                break
            end
            local instruction = instruction_list[index]
            local op = instruction.op

            state.current_instruction = instruction
            state.current_index = index
            state.current_op = op

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
                    scope:expectRegisterAsExpr(instructionab.b)
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
                    { scope:expectRegisterAsExpr(instructionacaux.a)}
                ))

            elseif op == common.LOP_GETUPVAL then
                local instructionab = instruction :: InstructionAB
                pushStat(scope:setSingleRegister(
                    instructionab.a,
                    getUpvalueExpr(instructionab.b)
                ))
            elseif op == common.LOP_SETUPVAL then
                local instructionab = instruction :: InstructionAB
                pushStat(ast.newAstStatAssign(
                    { getUpvalueExpr(instructionab.b) },
                    { scope:expectRegisterAsExpr(instructionab.a) }
                ))
            elseif op == common.LOP_CLOSEUPVALS then

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
                        scope:expectRegisterAsExpr(instructionabc.b),
                        scope:expectRegisterAsExpr(instructionabc.c)
                    )
                ))
            elseif op == common.LOP_SETTABLE then
                local instructionabc = instruction :: InstructionABC
                pushStat(ast.newAstStatAssign(
                    { ast.newAstExprIndexExpr(
                        scope:expectRegisterAsExpr(instructionabc.b),
                        scope:expectRegisterAsExpr(instructionabc.c)
                    ) },
                    { scope:expectRegisterAsExpr(instructionabc.a) }
                ))
            elseif op == common.LOP_GETTABLEKS then
                local instructionabcaux = instruction :: InstructionABCAUX
                pushStat(scope:setSingleRegister(
                    instructionabcaux.a,
                    tryToCleanIndex(ast.newAstExprIndexExpr(
                        scope:expectRegisterAsExpr(instructionabcaux.b),
                            getConstantExpr(constant_list[instructionabcaux.aux])
                    ))
                ))
            elseif op == common.LOP_SETTABLEKS then
                local instructionabcaux = instruction::InstructionABCAUX
                pushStat(ast.newAstStatAssign(
                    { ast.newAstExprIndexExpr(
                        scope:expectRegisterAsExpr(instructionabcaux.b),
                        getConstantExpr(constant_list[instructionabcaux.aux])
                    ) },
                    { scope:expectRegisterAsExpr(instructionabcaux.a) }
                ))
            elseif op == common.LOP_GETTABLEN then
                local instructionabc = instruction :: InstructionABC
                pushStat(scope:setSingleRegister(
                    instructionabc.a,
                    ast.newAstExprIndexExpr(
                        scope:expectRegisterAsExpr(instructionabc.b),
                        ast.newAstExprConstantNumber(instructionabc.c + 1)
                    )
                ))
            elseif op == common.LOP_SETTABLEN then
                local instructionabc = instruction :: InstructionABC
                pushStat(ast.newAstStatAssign(
                    { ast.newAstExprIndexExpr(
                        scope:expectRegisterAsExpr(instructionabc.b),
                        ast.newAstExprConstantNumber(instructionabc.c + 1)
                    ) },
                    { scope:expectRegisterAsExpr(instructionabc.a) }
                ))

            elseif op == common.LOP_NEWCLOSURE then
                local instructionad = instruction :: InstructionAD
                local name = scope:addProto(instructionad.d)
                pushStat(scope:setSingleRegister(instructionad.a,
                    ast.newAstExprLocal(ast.newAstLocal(name))
                ))

            elseif op == common.LOP_NAMECALL then
                local instructionabcaux = instruction :: InstructionABCAUX
                -- handled in call
                namecall_holder = instructionabcaux

                -- a+1 = b
                pushStat(scope:setSingleRegister(
                    instructionabcaux.a + 1,
                    scope:expectRegisterAsExpr(instructionabcaux.b)
                ))
                -- a = value
                -- pushStat(scope:setSingleRegister(
                --     instructionabcaux.a,
                --     tryToCleanIndex(ast.newAstExprIndexExpr(
                --         scope:expectRegisterAsExpr(instructionabcaux.a + 1),
                --             getConstantExpr(constant_list[instructionabcaux.aux])
                --     ))
                -- ))
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
                    local start = if namecall_holder then 2 else 1
                    for i = start, arg_count do
                        args[arg_count - i] = scope:expectRegisterAsExpr(func + i)
                    end
                end

                local all_results_new = true
                if result_count == -1 then
                    results[1] = ast.newAstLocal("!TOP!")
                else
                    local last_is_new: boolean | number = 0
                    for i = 1, result_count do
                        local variable, is_new = scope:getOrAddRegister(func + i - 1)
                        results[i] = variable.ast_local

                        if last_is_new == 0 then
                            last_is_new = is_new
                        else
                            if is_new ~= last_is_new then
                                is_new = false
                                -- error("is_new mismatch in CALL")
                            end
                        end

                        if not is_new then
                            all_results_new = false
                        end
                    end
                end

                local call_expr: AstExprCall
                if namecall_holder then
                    call_expr = ast.newAstExprCall(
                        ast.newAstExprIndexName(
                            scope:expectRegisterAsExpr(namecall_holder.b),
                            (constant_list[namecall_holder.aux]::ConstantString).string,
                            ':'
                        ),
                        args,
                        true
                    )
                    namecall_holder = nil
                else
                    call_expr = ast.newAstExprCall(
                        scope:expectRegisterAsExpr(instructionabc.a),
                        args,
                        false
                    )
                end

                pushStat(
                    if next(results) then
                        -- TODO: look into cases where this is an AstStatAssign
                        if all_results_new then
                            ast.newAstStatLocal(results, { call_expr })
                        else
                            ast.newAstStatAssign(getExpressionListFromAstLocalList(results), { call_expr })
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
                        list[i] = scope:expectRegisterAsExpr(start + i - 1)
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
                        scope:expectRegisterAsExpr(instructionabc.b),
                        scope:expectRegisterAsExpr(instructionabc.c)
                    )
                ))

            elseif op == common.LOP_CONCAT then
                local instructionabc = instruction :: InstructionABC
                local register_start = instructionabc.b
                local register_end = instructionabc.c

                local expr: AstExpr = scope:expectRegisterAsExpr(register_start)
                for i = register_start + 1, register_end do
                    expr = ast.newAstExprBinary(ast.BINARY_Concat,
                        expr,
                        scope:expectRegisterAsExpr(i)
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
                        scope:expectRegisterAsExpr(instructionabc.b),
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
                        scope:expectRegisterAsExpr(instructionab.b)
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
                            scope:expectRegisterAsExpr(target),
                            ast.newAstExprUnknown()
                        ) },
                        { ast.newAstExprTop() }
                    ))
                else
                    for i = 1, count do
                        pushStat(ast.newAstStatAssign(
                            { ast.newAstExprIndexExpr(
                                scope:expectRegisterAsExpr(target),
                                ast.newAstExprConstantNumber(i + aux - 1)
                            ) },
                            { scope:expectRegisterAsExpr(start + i - 1) }
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
                        local variable, is_new = scope:getOrAddRegister(target + i - 1)
                        results[i] = variable.ast_local

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
                        pushStat(ast.newAstStatAssign(
                            getExpressionListFromAstLocalList(results),
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
                local instructiona = instruction :: InstructionA

                -- pushStat(ast.newAstStatComment(" prep varargs"))
                if instructiona.a > 0 then
                    pushStat(scope:setRegisterListSingleExpr(
                        0,
                        instructiona.a,
                        ast.newAstExprVarargs()
                    ))
                end

            elseif op == common.LOP_LOADKX then
                local instructionaaux = instruction :: InstructionAAUX
                pushStat(scope:setSingleRegister(
                    instructionaaux.a,
                    getConstantExpr(constant_list[instructionaaux.aux])
                ))

            -- TODO: jumpx

            -- TODO: fastcall

            elseif op == common.LOP_COVERAGE then

            -- TODO: capture
            -- elseif op == common.LOP_CAPTURE then
            --     local instructionab = instruction :: InstructionAB

            elseif op == common.LOP_SUBRK or op == common.LOP_DIVRK then
                local instructionabc = instruction :: InstructionABC
                pushStat(scope:setSingleRegister(
                    instructionabc.a,
                    ast.newAstExprBinary(BINARY_LOP_TO_OP_MAP[op],
                        getConstantExpr(constant_list[instructionabc.b]),
                        scope:expectRegisterAsExpr(instructionabc.c)
                    )
                ))

            -- TODO: fastcall1 through 2k

            -- TODO: forgprep

            -- TODO: jumpxeqknil through jumpxeqks
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
    -- fold(result_block)
    return result_block
end
local function decompile(arg1: string | buffer | Proto): string
    local proto = tryToGetProto(arg1, deserialize)
    local ast_stat = decompileProto(proto)

    return astToString(ast_stat)
end

return decompile