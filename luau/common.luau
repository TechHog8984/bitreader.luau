--!strict

--[[
    luau/common.luau
    part of https://github.com/TechHog8984/bitreader.luau
    by techhog
    see LICENSE

    target luau version: 0.635
]]

local bor = bit32.bor
local band = bit32.band
local rshift = bit32.rshift
local lshift = bit32.lshift

local enum do
    local highest = 0
    enum = function(explicit: number?): number
        if explicit then
            highest = explicit - 1
        end
        highest += 1
        return highest
    end
end

local STRING_ESCAPE_MAP = {
    ['\a'] = 'a',
    ['\b'] = 'b',
    ['\n'] = 'n',
    ['\r'] = 'r',
    ['\t'] = 't',
    ['\v'] = 'v',
    ['\\'] = '\\',
    ['"'] = '"',
    ['\0'] = '0'
}
local function formatString(str: string, omit_quotes: boolean?): string
    str = (str:gsub('.', function(ch)
        local escape = STRING_ESCAPE_MAP[ch]
        if escape then
            return '\\' .. escape
        end
        return ch
    end))

    if omit_quotes then
        return str
    end

    return '"' .. str .. '"'
end

local LBC_VERSION_MIN = 3
local LBC_VERSION_MAX = 6

local LBC_TYPE_VERSION_MIN = 1
local LBC_TYPE_VERSION_MAX = 3

local LBC_TYPE_TAGGED_USERDATA_BASE = 64
local LBC_TYPE_TAGGED_USERDATA_END = 64 + 32

local LBC_TYPE_NIL = enum(0)
local LBC_TYPE_BOOLEAN = enum()
local LBC_TYPE_NUMBER = enum()
local LBC_TYPE_STRING = enum()
local LBC_TYPE_TABLE = enum()
local LBC_TYPE_FUNCTION = enum()
local LBC_TYPE_THREAD = enum()
local LBC_TYPE_USERDATA = enum()
local LBC_TYPE_VECTOR = enum()
local LBC_TYPE_BUFFER = enum()

local LBC_CONSTANT_NIL = enum(0)
local LBC_CONSTANT_BOOLEAN = enum()
local LBC_CONSTANT_NUMBER = enum()
local LBC_CONSTANT_STRING = enum()
local LBC_CONSTANT_IMPORT = enum()
local LBC_CONSTANT_TABLE = enum()
local LBC_CONSTANT_CLOSURE = enum()
local LBC_CONSTANT_VECTOR = enum()

local LBC_CONSTANT_MIN = 0
local LBC_CONSTANT_MAX = LBC_CONSTANT_VECTOR

type BaseConstant = {
    t: number,
    format: (Constant, boolean?) -> string
}
export type ConstantNil = BaseConstant
export type ConstantBoolean = BaseConstant & {
    bool: boolean
}
export type ConstantNumber = BaseConstant & {
    number: number
}
export type ConstantString = BaseConstant & {
    string: string
}
export type ConstantImport = BaseConstant & {
    import: string
}
export type ConstantTable = BaseConstant & {
    table: { [string]: any }
}

export type Closure = {
    proto: Proto
}
export type ConstantClosure = BaseConstant & {
    closure: Closure
}

export type Vector = {
    x: number,
    y: number,
    z: number,
    w: number
}

export type ConstantVector = BaseConstant & {
    vector: Vector
}

export type Constant = ConstantNil | ConstantBoolean |
    ConstantNumber | ConstantString | ConstantImport |
    ConstantTable | ConstantClosure | ConstantVector

export type LocVar = {
    var_name: string,
    start_pc: number,
    end_pc: number,
    reg: number
}

type JumpTarget = {
    conditional: boolean,
    target: number
}
type BaseInstruction = { op: number, index: number, format: (Instruction) -> string, getJumpTarget: (Instruction) -> JumpTarget }

export type InstructionSpecial = BaseInstruction & {
    is_nop: boolean,
    is_break: boolean
}
-- some don't have BaseInstruction since they are never used by themselves
export type InstructionA = BaseInstruction & { a: number }
export type InstructionB = { b: number }
export type InstructionC = { c: number }
export type InstructionD = BaseInstruction & { d: number }
export type InstructionE = BaseInstruction & { e: number }
export type InstructionAUX = { aux: number }

export type InstructionAB = InstructionA & InstructionB
export type InstructionAC = InstructionA & InstructionC
export type InstructionAD = InstructionA & InstructionD
export type InstructionAAUX = InstructionA & InstructionAUX

export type InstructionABC = InstructionAB & InstructionAC
export type InstructionABAUX = InstructionAB & InstructionAUX
export type InstructionACAUX = InstructionAC & InstructionAUX
export type InstructionADAUX = InstructionAD & InstructionAUX

export type InstructionABCAUX = InstructionABC & InstructionAUX

export type Instruction = BaseInstruction & (InstructionSpecial | InstructionA | InstructionD | InstructionE |
    InstructionAB | InstructionAC | InstructionAD | InstructionAAUX |
    InstructionABC | InstructionABAUX | InstructionACAUX |
    InstructionADAUX | InstructionABCAUX)

export type Proto = {
    bytecode_id: number,

    max_stack_size: number,
    num_params: number,
    num_upvalues: number,
    is_vararg: boolean,

    flags: number?,

    instructions: { Instruction },
    size_instructions: number,

    constant_list: { Constant },
    constant_count: number,

    proto_list: { Proto },
    proto_count: number,
    line_defined: number,
    debug_name: string,

    -- line_gap_log2: number?,
    -- line_info: { number }?,
    -- abs_line_info: { number }?,
    -- line_info_count: number?,
    -- line_info_abs_offset: number?,

    loc_var_list: { LocVar }?,
    loc_var_count: number?,

    upvalue_list: { string }?,
    upvalue_count: number?,
}

local Constant = {}

local CONSTANT_TYPE_NAME_MAP = {
    [LBC_CONSTANT_NIL] = "nil",
    [LBC_CONSTANT_BOOLEAN] = "boolean",
    [LBC_CONSTANT_NUMBER] = "number",
    [LBC_CONSTANT_STRING] = "string",
    [LBC_CONSTANT_IMPORT] = "import",
    [LBC_CONSTANT_TABLE] = "table",
    [LBC_CONSTANT_CLOSURE] = "closure",
    [LBC_CONSTANT_VECTOR] = "vector",
}

function formatConstant(self: Constant, omit_type: boolean?): string
    local result = "nil"
    if self.t == LBC_CONSTANT_NIL then
    elseif self.t == LBC_CONSTANT_BOOLEAN then
        result = if (self::ConstantBoolean).bool then "true" else "false"
    elseif self.t == LBC_CONSTANT_NUMBER then
        result = tostring((self::ConstantNumber).number)
    elseif self.t == LBC_CONSTANT_STRING then
        result = formatString((self::ConstantString).string)
    elseif self.t == LBC_CONSTANT_IMPORT then
        result = (self::ConstantImport).import
    elseif self.t == LBC_CONSTANT_TABLE then
        local t = (self::ConstantTable).table
        local body = ""

        for k in t do
            body ..= k .. " = ?, "
        end
        if next(t) then
            body = body:sub(1, -3)
        end

        result = '{' .. body .. '}'
    elseif self.t == LBC_CONSTANT_CLOSURE then
        result = "closure with proto_" .. (self::ConstantClosure).closure.proto.bytecode_id
    elseif self.t == LBC_CONSTANT_VECTOR then
        local vector = (self::ConstantVector).vector
        result = "{x = " .. vector.x .. ", y = " .. vector.y ..
            ", z = " .. vector.z .. ", w = " .. vector.w .. '}'
    else
        error("INVALID CONSTANT TYPE " .. tostring(self.t))
    end

    if omit_type then
        return result
    end
    return result .. " -- " .. CONSTANT_TYPE_NAME_MAP[self.t]
end

local CONSTANT_TYPE_TO_KEY_MAP = {
    [LBC_CONSTANT_NIL] = "",
    [LBC_CONSTANT_BOOLEAN] = "bool",
    [LBC_CONSTANT_NUMBER] = "number",
    [LBC_CONSTANT_STRING] = "string",
    [LBC_CONSTANT_IMPORT] = "import",
    [LBC_CONSTANT_TABLE] = "table",
    [LBC_CONSTANT_CLOSURE] = "closure",
    [LBC_CONSTANT_VECTOR] = "vector",
}
function Constant.new(t: number, value: any?): Constant
    assert(t >= LBC_CONSTANT_NIL and t <= LBC_CONSTANT_VECTOR, "constant type " .. t .. " is out of range (" .. LBC_CONSTANT_MIN .. ".." .. LBC_CONSTANT_MAX .. ')')

    local constant = {
        t = t,
        [CONSTANT_TYPE_TO_KEY_MAP[t] or error("INVALID CONSTANT TYPE " .. tostring(t))] = value,
    }

    constant.format = formatConstant

    return constant :: Constant
end

local function tryToGetProto(arg1: string | buffer | Proto, deserialize: (string | buffer) -> Proto): Proto
    local proto: Proto
    if type(arg1) == "string" or type(arg1) == "buffer" then
        proto = deserialize(arg1)
    else
        proto = arg1
    end
    assert(proto)

    return proto
end

-- NOP: noop
local LOP_NOP = enum(0)
-- BREAK: debugger break
local LOP_BREAK = enum()
-- LOADNIL: sets register to nil
-- A: target register
local LOP_LOADNIL = enum()
-- LOADB: sets register to boolean and jumps to a given short offset (used to compile comparison results into a boolean)
-- A: target register
-- B: value (0/1)
-- C: jump offset
local LOP_LOADB = enum()
-- LOADN: sets register to a number literal
-- A: target register
-- D: value (-32768..32767)
local LOP_LOADN = enum()
-- LOADK: sets register to an entry from the constant table from the proto (number/vector/string)
-- A: target register
-- D: constant table index (0..32767)
local LOP_LOADK = enum()
-- MOVE: move (copy) value from one register to another
-- A: target register
-- B: source register
local LOP_MOVE = enum()
-- GETGLOBAL: load value from global table using constant string as a key
-- A: target register
-- C: predicted slot index (based on hash)
-- AUX: constant table index
local LOP_GETGLOBAL = enum()
-- SETGLOBAL: set value in global table using constant string as a key
-- A: source register
-- C: predicted slot index (based on hash)
-- AUX: constant table index
local LOP_SETGLOBAL = enum()
-- GETUPVAL: load upvalue from the upvalue table for the current function
-- A: target register
-- B: upvalue index
local LOP_GETUPVAL = enum()
-- SETUPVAL: store value into the upvalue table for the current function
-- A: target register
-- B: upvalue index
local LOP_SETUPVAL = enum()
-- CLOSEUPVALS: close (migrate to heap) all upvalues that were captured for registers >= target
-- A: target register
local LOP_CLOSEUPVALS = enum()
-- GETIMPORT: load imported global table global from the constant table
-- A: target register
-- D: constant table index (0..32767); we assume that imports are loaded into the constant table
-- AUX: 3 10-bit indices of constant strings that, combined, constitute an import path; length of the path is set by the top 2 bits (1,2,3)
local LOP_GETIMPORT = enum()
-- GETTABLE: load value from table into target register using key from register
-- A: target register
-- B: table register
-- C: index register
local LOP_GETTABLE = enum()
-- SETTABLE: store source register into table using key from register
-- A: source register
-- B: table register
-- C: index register
local LOP_SETTABLE = enum()
-- GETTABLEKS: load value from table into target register using constant string as a key
-- A: target register
-- B: table register
-- C: predicted slot index (based on hash)
-- AUX: constant table index
local LOP_GETTABLEKS = enum()
-- SETTABLEKS: store source register into table using constant string as a key
-- A: source register
-- B: table register
-- C: predicted slot index (based on hash)
-- AUX: constant table index
local LOP_SETTABLEKS = enum()
-- GETTABLEN: load value from table into target register using small integer index as a key
-- A: target reagister
-- B: table register
-- C: index-1 (index is 1..256)
local LOP_GETTABLEN = enum()
-- SETTABLEN: store source register into table using small integer index as a key
-- A: source register
-- B: table register
-- C: index-1 (index is 1..256)
local LOP_SETTABLEN = enum()
-- NEWCLOSURE: create closure from a child proto; followed by a CAPTURE instruction for each upvalue
-- A: target register
-- D: child proto index (0..32767)
local LOP_NEWCLOSURE = enum()
-- NAMECALL: prepare to call specified method by name by loading function from source register using constant index into target register and copying source register into target register + 1
-- A: target register
-- B: source register
-- C: predicted slot index (based on hash)
-- AUX: constant table index
-- Note that this instruction must be followed directly by CALL; it prepares the arguments
-- This instruction is roughly equivalent to GETTABLEKS + MOVE pair, but we need a special instruction to support custom __namecall metamethod
local LOP_NAMECALL = enum()
-- CALL: call specified function
-- A: register where the function object lives, followed by arguments; results are placed starting from the same register
-- B: argument count + 1, or 0 to preserve all arguments up to top (MULTRET)
-- C: result count + 1, or 0 to preserve all values and adjust top (MULTRET)
local LOP_CALL = enum()
-- RETURN: returns specified values from the function
-- A: register where the returned values start
-- B: number of returned values + 1, or 0 to return all values up to top (MULTRET)
local LOP_RETURN = enum()
-- JUMP: jumps to target offset
-- D: jump offset (-32768..32767; 0 means "next instruction" aka "don't jump")
local LOP_JUMP = enum()
-- JUMPBACK: jumps to target offset; this is equivalent to JUMP but is used as a safepoint to be able to interrupt while/repeat loops
-- D: jump offset (-32768..32767; 0 means "next instruction" aka "don't jump")
local LOP_JUMPBACK = enum()
-- JUMPIF: jumps to target offset if register is not nil/false
-- A: source register
-- D: jump offset (-32768..32767; 0 means "next instruction" aka "don't jump")
local LOP_JUMPIF = enum()
-- JUMPIFNOT: jumps to target offset if register is nil/false
-- A: source register
-- D: jump offset (-32768..32767; 0 means "next instruction" aka "don't jump")
local LOP_JUMPIFNOT = enum()
-- JUMPIFEQ, JUMPIFLE, JUMPIFLT, JUMPIFNOTEQ, JUMPIFNOTLE, JUMPIFNOTLT: jumps to target offset if the comparison is true (or false, for NOT variants)
-- A: source register 1
-- D: jump offset (-32768..32767; 1 means "next instruction" aka "don't jump")
-- AUX: source register 2
local LOP_JUMPIFEQ = enum()
local LOP_JUMPIFLE = enum()
local LOP_JUMPIFLT = enum()
local LOP_JUMPIFNOTEQ = enum()
local LOP_JUMPIFNOTLE = enum()
local LOP_JUMPIFNOTLT = enum()
-- ADD, SUB, MUL, DIV, MOD, POW: compute arithmetic operation between two source registers and put the result into target register
-- A: target register
-- B: source register 1
-- C: source register 2
local LOP_ADD = enum()
local LOP_SUB = enum()
local LOP_MUL = enum()
local LOP_DIV = enum()
local LOP_MOD = enum()
local LOP_POW = enum()
-- ADDK, SUBK, MULK, DIVK, MODK, POWK: compute arithmetic operation between the source register and a constant and put the result into target register
-- A: target register
-- B: source register
-- C: constant table index (0..255); must refer to a number
local LOP_ADDK = enum()
local LOP_SUBK = enum()
local LOP_MULK = enum()
local LOP_DIVK = enum()
local LOP_MODK = enum()
local LOP_POWK = enum()
-- AND, OR: perform `and` or `or` operation (selecting first or second register based on whether the first one is truthy) and put the result into target register
-- A: target register
-- B: source register 1
-- C: source register 2
local LOP_AND = enum()
local LOP_OR = enum()
-- ANDK, ORK: perform `and` or `or` operation (selecting source register or constant based on whether the source register is truthy) and put the result into target register
-- A: target register
-- B: source register
-- C: constant table index (0..255)
local LOP_ANDK = enum()
local LOP_ORK = enum()
-- CONCAT: concatenate all strings between B and C (inclusive) and put the result into A
-- A: target register
-- B: source register start
-- C: source register end
local LOP_CONCAT = enum()
-- NOT, MINUS, LENGTH: compute unary operation for source register and put the result into target register
-- A: target register
-- B: source register
local LOP_NOT = enum()
local LOP_MINUS = enum()
local LOP_LENGTH = enum()
-- NEWTABLE: create table in target register
-- A: target register
-- B: table size, stored as 0 for v=0 and ceil(log2(v))+1 for v!=0
-- AUX: array size
local LOP_NEWTABLE = enum()
-- DUPTABLE: duplicate table using the constant table template to target register
-- A: target register
-- D: constant table index (0..32767)
local LOP_DUPTABLE = enum()
-- SETLIST: set a list of values to table in target register
-- A: target register
-- B: source register start
-- C: value count + 1, or 0 to use all values up to top (MULTRET)
-- AUX: table index to start from
local LOP_SETLIST = enum()
-- FORNPREP: prepare a numeric for loop, jump over the loop if first iteration doesn't need to run
-- A: target register; numeric for loops assume a register layout [limit, step, index, variable]
-- D: jump offset (-32768..32767)
-- limit/step are immutable, index isn't visible to user code since it's copied into variable
local LOP_FORNPREP = enum()
-- FORNLOOP: adjust loop variables for one iteration, jump back to the loop header if loop needs to continue
-- A: target register; see FORNPREP for register layout
-- D: jump offset (-32768..32767)
local LOP_FORNLOOP = enum()
-- FORGLOOP: adjust loop variables for one iteration of a generic for loop, jump back to the loop header if loop needs to continue
-- A: target register; generic for loops assume a register layout [generator, state, index, variables...]
-- D: jump offset (-32768..32767)
-- AUX: variable count (1..255) in the low 8 bits, high bit indicates whether to use ipairs-style traversal in the fast path
-- loop variables are adjusted by calling generator(state, index) and expecting it to return a tuple that's copied to the user variables
-- the first variable is then copied into index; generator/state are immutable, index isn't visible to user code
local LOP_FORGLOOP = enum()
-- FORGPREP_INEXT: prepare FORGLOOP with 2 output variables (no AUX encoding), assuming generator is luaB_inext, and jump to FORGLOOP
-- A: target register (see FORGLOOP for register layout)
local LOP_FORGPREP_INEXT = enum()
-- FASTCALL3: perform a fast call of a built-in function using 3 register arguments
-- A: builtin function id (see LuauBuiltinFunction)
-- B: source argument register
-- C: jump offset to get to following CALL
-- AUX: source register 2 in least-significant byte
-- AUX: source register 3 in second least-significant byte
local LOP_FASTCALL3 = enum()

-- FORGPREP_NEXT: prepare FORGLOOP with 2 output variables (no AUX encoding), assuming generator is luaB_next, and jump to FORGLOOP
-- A: target register (see FORGLOOP for register layout)
local LOP_FORGPREP_NEXT = enum()
-- NATIVECALL: start executing new function in native code
-- this is a pseudo-instruction that is never emitted by bytecode compiler, but can be constructed at runtime to accelerate native code dispatch
local LOP_NATIVECALL = enum()
-- GETVARARGS: copy variables into the target register from vararg storage for current function
-- A: target register
-- B: variable count + 1, or 0 to copy all variables and adjust top (MULTRET)
local LOP_GETVARARGS = enum()
-- DUPCLOSURE: create closure from a pre-created function object (reusing it unless environments diverge)
-- A: target register
-- D: constant table index (0..32767)
local LOP_DUPCLOSURE = enum()
-- PREPVARARGS: prepare stack for variadic functions so that GETVARARGS works correctly
-- A: number of fixed arguments
local LOP_PREPVARARGS = enum()
-- LOADKX: sets register to an entry from the constant table from the proto (number/string)
-- A: target register
-- AUX: constant table index
local LOP_LOADKX = enum()
-- JUMPX: jumps to the target offset; like JUMPBACK, supports interruption
-- E: jump offset (-2^23..2^23; 0 means "next instruction" aka "don't jump")
local LOP_JUMPX = enum()
-- FASTCALL: perform a fast call of a built-in function
-- A: builtin function id (see LuauBuiltinFunction)
-- C: jump offset to get to following CALL
-- FASTCALL is followed by one of (GETIMPORT, MOVE, GETUPVAL) instructions and by CALL instruction
-- This is necessary so that if FASTCALL can't perform the call inline, it can continue normal execution
-- If FASTCALL *can* perform the call, it jumps over the instructions *and* over the next CALL
-- Note that FASTCALL will read the actual call arguments, such as argument/result registers and counts, from the CALL instruction
local LOP_FASTCALL = enum()
-- COVERAGE: update coverage information stored in the instruction
-- E: hit count for the instruction (0..2^23-1)
-- The hit count is incremented by VM every time the instruction is executed, and saturates at 2^23-1
local LOP_COVERAGE = enum()
-- CAPTURE: capture a local or an upvalue as an upvalue into a newly created closure; only valid after NEWCLOSURE
-- A: capture type, see LuauCaptureType
-- B: source register (for VAL/REF) or upvalue index (for UPVAL/UPREF)
local LOP_CAPTURE = enum()
-- SUBRK, DIVRK: compute arithmetic operation between the constant and a source register and put the result into target register
-- A: target register
-- B: constant table index (0..255); must refer to a number
-- C: source register
local LOP_SUBRK = enum()
local LOP_DIVRK = enum()
-- FASTCALL1: perform a fast call of a built-in function using 1 register argument
-- A: builtin function id (see LuauBuiltinFunction)
-- B: source argument register
-- C: jump offset to get to following CALL
local LOP_FASTCALL1 = enum()

-- FASTCALL2: perform a fast call of a built-in function using 2 register arguments
-- A: builtin function id (see LuauBuiltinFunction)
-- B: source argument register
-- C: jump offset to get to following CALL
-- AUX: source register 2 in least-significant byte
local LOP_FASTCALL2 = enum()

-- FASTCALL2K: perform a fast call of a built-in function using 1 register argument and 1 constant argument
-- A: builtin function id (see LuauBuiltinFunction)
-- B: source argument register
-- C: jump offset to get to following CALL
-- AUX: constant index
local LOP_FASTCALL2K = enum()

-- FORGPREP: prepare loop variables for a generic for loop, jump to the loop backedge unconditionally
-- A: target register; generic for loops assume a register layout [generator, state, index, variables...]
-- D: jump offset (-32768..32767)
local LOP_FORGPREP = enum()
-- JUMPXEQKNIL, JUMPXEQKB: jumps to target offset if the comparison with constant is true (or false, see AUX)
-- A: source register 1
-- D: jump offset (-32768..32767; 1 means "next instruction" aka "don't jump")
-- AUX: constant value (for boolean) in low bit, NOT flag (that flips comparison result) in high bit
local LOP_JUMPXEQKNIL = enum()
local LOP_JUMPXEQKB = enum()
-- JUMPXEQKN, JUMPXEQKS: jumps to target offset if the comparison with constant is true (or false, see AUX)
-- A: source register 1
-- D: jump offset (-32768..32767; 1 means "next instruction" aka "don't jump")
-- AUX: constant table index in low 24 bits, NOT flag (that flips comparison result) in high bit
local LOP_JUMPXEQKN = enum()
local LOP_JUMPXEQKS = enum()
-- IDIV: compute floor division between two source registers and put the result into target register
-- A: target register
-- B: source register 1
-- C: source register 2
local LOP_IDIV = enum()
-- IDIVK compute floor division between the source register and a constant and put the result into target register
-- A: target register
-- B: source register
-- C: constant table index (0..255)
local LOP_IDIVK = enum()
-- Enum entry for number of opcodes, not a valid opcode by itself!
local LOP__COUNT = enum()

local OP_TOSTRING_MAP: { [number]: string } = {
    [LOP_NOP] = "LOP_NOP",

    [LOP_BREAK] = "LOP_BREAK",

    [LOP_LOADNIL] = "LOP_LOADNIL",
    [LOP_LOADB] = "LOP_LOADB",
    [LOP_LOADN] = "LOP_LOADN",
    [LOP_LOADK] = "LOP_LOADK",
    [LOP_MOVE] = "LOP_MOVE",

    [LOP_GETGLOBAL] = "LOP_GETGLOBAL",
    [LOP_SETGLOBAL] = "LOP_SETGLOBAL",

    [LOP_GETUPVAL] = "LOP_GETUPVAL",
    [LOP_SETUPVAL] = "LOP_SETUPVAL",
    [LOP_CLOSEUPVALS] = "LOP_CLOSEUPVALS",

    [LOP_GETIMPORT] = "LOP_GETIMPORT",

    [LOP_GETTABLE] = "LOP_GETTABLE",
    [LOP_SETTABLE] = "LOP_SETTABLE",
    [LOP_GETTABLEKS] = "LOP_GETTABLEKS",
    [LOP_SETTABLEKS] = "LOP_SETTABLEKS",
    [LOP_GETTABLEN] = "LOP_GETTABLEN",
    [LOP_SETTABLEN] = "LOP_SETTABLEN",

    [LOP_NEWCLOSURE] = "LOP_NEWCLOSURE",
    [LOP_NAMECALL] = "LOP_NAMECALL",
    [LOP_CALL] = "LOP_CALL",
    [LOP_RETURN] = "LOP_RETURN",

    [LOP_JUMP] = "LOP_JUMP",
    [LOP_JUMPBACK] = "LOP_JUMPBACK",
    [LOP_JUMPIF] = "LOP_JUMPIF",
    [LOP_JUMPIFNOT] = "LOP_JUMPIFNOT",
    [LOP_JUMPIFEQ] = "LOP_JUMPIFEQ",
    [LOP_JUMPIFLE] = "LOP_JUMPIFLE",
    [LOP_JUMPIFLT] = "LOP_JUMPIFLT",
    [LOP_JUMPIFNOTEQ] = "LOP_JUMPIFNOTEQ",
    [LOP_JUMPIFNOTLE] = "LOP_JUMPIFNOTLE",
    [LOP_JUMPIFNOTLT] = "LOP_JUMPIFNOTLT",

    [LOP_ADD] = "LOP_ADD",
    [LOP_SUB] = "LOP_SUB",
    [LOP_MUL] = "LOP_MUL",
    [LOP_DIV] = "LOP_DIV",
    [LOP_MOD] = "LOP_MOD",
    [LOP_POW] = "LOP_POW",

    [LOP_ADDK] = "LOP_ADDK",
    [LOP_SUBK] = "LOP_SUBK",
    [LOP_MULK] = "LOP_MULK",
    [LOP_DIVK] = "LOP_DIVK",
    [LOP_MODK] = "LOP_MODK",
    [LOP_POWK] = "LOP_POWK",

    [LOP_AND] = "LOP_AND",
    [LOP_OR] = "LOP_OR",
    [LOP_ANDK] = "LOP_ANDK",
    [LOP_ORK] = "LOP_ORK",
    [LOP_CONCAT] = "LOP_CONCAT",

    [LOP_NOT] = "LOP_NOT",
    [LOP_MINUS] = "LOP_MINUS",
    [LOP_LENGTH] = "LOP_LENGTH",

    [LOP_NEWTABLE] = "LOP_NEWTABLE",
    [LOP_DUPTABLE] = "LOP_DUPTABLE",
    [LOP_SETLIST] = "LOP_SETLIST",

    [LOP_FORNPREP] = "LOP_FORNPREP",
    [LOP_FORNLOOP] = "LOP_FORNLOOP",
    [LOP_FORGLOOP] = "LOP_FORGLOOP",
    [LOP_FORGPREP_INEXT] = "LOP_FORGPREP_INEXT",

    [LOP_FASTCALL3] = "LOP_FASTCALL3",
    [LOP_FORGPREP_NEXT] = "LOP_FORGPREP_NEXT",

    [LOP_NATIVECALL] = "LOP_NATIVECALL",

    [LOP_GETVARARGS] = "LOP_GETVARARGS",

    [LOP_DUPCLOSURE] = "LOP_DUPCLOSURE",

    [LOP_PREPVARARGS] = "LOP_PREPVARARGS",

    [LOP_LOADKX] = "LOP_LOADKX",

    [LOP_JUMPX] = "LOP_JUMPX",

    [LOP_FASTCALL] = "LOP_FASTCALL",

    [LOP_COVERAGE] = "LOP_COVERAGE",

    [LOP_CAPTURE] = "LOP_CAPTURE",

    [LOP_SUBRK] = "LOP_SUBRK",
    [LOP_DIVRK] = "LOP_DIVRK",

    [LOP_FASTCALL1] = "LOP_FASTCALL1",
    [LOP_FASTCALL2] = "LOP_FASTCALL2",
    [LOP_FASTCALL2K] = "LOP_FASTCALL2K",

    [LOP_FORGPREP] = "LOP_FORGPREP",

    [LOP_JUMPXEQKNIL] = "LOP_JUMPXEQKNIL",
    [LOP_JUMPXEQKB] = "LOP_JUMPXEQKB",
    [LOP_JUMPXEQKN] = "LOP_JUMPXEQKN",
    [LOP_JUMPXEQKS] = "LOP_JUMPXEQKS",

    [LOP_IDIV] = "LOP_IDIV",
    [LOP_IDIVK] = "LOP_IDIVK",

    [LOP__COUNT] = "LOP__COUNT",
}
local function tostringOp(op: number): string
    return OP_TOSTRING_MAP[op] or ("UNKNOWN" .. tostring(op))
end

type number_to_boolean = { [number]: boolean }
local INSTRUCTION_SPECIAL_MAP: number_to_boolean = {
    [LOP_NOP] = true,
    [LOP_BREAK] = true
}
local INSTRUCTION_A_MAP: number_to_boolean = {
    [LOP_LOADNIL] = true,
    [LOP_CLOSEUPVALS] = true,
    [LOP_FORGPREP_INEXT] = true,
    [LOP_FORGPREP_NEXT] = true,
    [LOP_PREPVARARGS] = true,
}
local INSTRUCTION_D_MAP: number_to_boolean = {
    [LOP_JUMP] = true,
    [LOP_JUMPBACK] = true
}
local INSTRUCTION_E_MAP: number_to_boolean = {
    [LOP_JUMPX] = true,
    [LOP_COVERAGE] = true
}

local INSTRUCTION_AB_MAP: number_to_boolean = {
    [LOP_MOVE] = true,
    [LOP_GETUPVAL] = true,
    [LOP_SETUPVAL] = true,
    [LOP_RETURN] = true,
    [LOP_GETVARARGS] = true,
    [LOP_CAPTURE] = true,
    [LOP_NOT] = true,
    [LOP_MINUS] = true,
    [LOP_LENGTH] = true,
}
local INSTRUCTION_AC_MAP: number_to_boolean = {
    [LOP_FASTCALL] = true,
}
local INSTRUCTION_AD_MAP: number_to_boolean = {
    [LOP_LOADN] = true,
    [LOP_LOADK] = true,
    [LOP_NEWCLOSURE] = true,
    [LOP_JUMPIF] = true,
    [LOP_JUMPIFNOT] = true,
    [LOP_DUPTABLE] = true,
    [LOP_FORNPREP] = true,
    [LOP_FORNLOOP] = true,
    [LOP_DUPCLOSURE] = true,
    [LOP_FORGPREP] = true,
    [LOP_JUMPXEQKNIL] = true
}
local INSTRUCTION_AAUX_MAP: number_to_boolean = {
    [LOP_LOADKX] = true
}

local INSTRUCTION_ABC_MAP: number_to_boolean = {
    [LOP_LOADB] = true,
    [LOP_GETTABLE] = true,
    [LOP_SETTABLE] = true,
    [LOP_GETTABLEN] = true,
    [LOP_SETTABLEN] = true,
    [LOP_CALL] = true,
    [LOP_ADD] = true,
    [LOP_SUB] = true,
    [LOP_MUL] = true,
    [LOP_DIV] = true,
    [LOP_MOD] = true,
    [LOP_POW] = true,
    [LOP_ADDK] = true,
    [LOP_SUBK] = true,
    [LOP_MULK] = true,
    [LOP_DIVK] = true,
    [LOP_MODK] = true,
    [LOP_POWK] = true,
    [LOP_AND] = true,
    [LOP_OR] = true,
    [LOP_ANDK] = true,
    [LOP_ORK] = true,
    [LOP_CONCAT] = true,
    [LOP_SUBRK] = true,
    [LOP_DIVRK] = true,
    [LOP_FASTCALL1] = true,
    [LOP_IDIV] = true,
    [LOP_IDIVK] = true,
}
local INSTRUCTION_ABAUX_MAP: number_to_boolean = {
    [LOP_NEWTABLE] = true
}
local INSTRUCTION_ACAUX_MAP: number_to_boolean = {
    [LOP_GETGLOBAL] = true,
    [LOP_SETGLOBAL] = true
}
local INSTRUCTION_ADAUX_MAP: number_to_boolean = {
    [LOP_GETIMPORT] = true,
    [LOP_JUMPIFEQ] = true,
    [LOP_JUMPIFLE] = true,
    [LOP_JUMPIFLT] = true,
    [LOP_JUMPIFNOTEQ] = true,
    [LOP_JUMPIFNOTLE] = true,
    [LOP_JUMPIFNOTLT] = true,
    [LOP_FORGLOOP] = true,
    [LOP_JUMPXEQKB] = true,
    [LOP_JUMPXEQKN] = true,
    [LOP_JUMPXEQKS] = true,
}

local INSTRUCTION_ABCAUX_MAP: number_to_boolean = {
    [LOP_NAMECALL] = true,
    [LOP_GETTABLEKS] = true,
    [LOP_SETTABLEKS] = true,
    [LOP_SETLIST] = true,
    [LOP_FASTCALL3] = true,
    [LOP_FASTCALL2] = true,
    [LOP_FASTCALL2K] = true,
}

local INSTRUCTION_ANYAUX_MAP: number_to_boolean = {} do
    local function push(map: number_to_boolean)
        for k in map do
            INSTRUCTION_ANYAUX_MAP[k] = true
        end
    end

    push(INSTRUCTION_AAUX_MAP)

    push(INSTRUCTION_ABAUX_MAP)
    push(INSTRUCTION_ACAUX_MAP)
    push(INSTRUCTION_ADAUX_MAP)

    push(INSTRUCTION_ABCAUX_MAP)
end

local CONSTANT_B_MAP: number_to_boolean = {
    [LOP_SUBRK] = true,
    [LOP_DIVRK] = true
}
local CONSTANT_C_MAP: number_to_boolean = {
    [LOP_ADDK] = true,
    [LOP_SUBK] = true,
    [LOP_MULK] = true,
    [LOP_DIVK] = true,
    [LOP_MODK] = true,
    [LOP_POWK] = true,

    [LOP_ANDK] = true,
    [LOP_ORK] = true,

    [LOP_IDIVK] = true
}
local CONSTANT_D_MAP: number_to_boolean = {
    [LOP_LOADK] = true,
    [LOP_GETIMPORT] = true,
    [LOP_DUPTABLE] = true,
    [LOP_DUPCLOSURE] = true
}
local CONSTANT_AUX_MAP: number_to_boolean = {
    [LOP_GETGLOBAL] = true,
    [LOP_SETGLOBAL] = true,

    [LOP_GETTABLEKS] = true,
    [LOP_SETTABLEKS] = true,

    [LOP_NAMECALL] = true,

    [LOP_LOADKX] = true,

    [LOP_FASTCALL2K] = true
}
local CONSTANT_AUX_LOW24BITS: number_to_boolean = {
    [LOP_JUMPXEQKN] = true,
    [LOP_JUMPXEQKS] = true
}
local CONSTANT_AUX_LOWBIT: number_to_boolean = {
    [LOP_JUMPXEQKB] = true
}

type valid_arg = "a" | "b" | "c" | "d" | "e" | "aux"
local ARG_CONSTANT_TABLE_MAP: { [valid_arg]: number_to_boolean } = {
    a = {},
    b = CONSTANT_B_MAP,
    c = CONSTANT_C_MAP,
    d = CONSTANT_D_MAP,
    e = {},
    aux = CONSTANT_AUX_MAP
}

local function uint8(num: number): number
    return bit32.extract(num, 0, 8)
end
-- FIXME: test int16 and int24
local function int16(num: number): number
    return bit32.extract(num, 0, 16)
end
local function int24(num: number): number
    return bit32.extract(num, 0, 24)
end

local function getOp(insn: number): number
    return uint8(band(insn, 0xff))
end

local function getA(insn: number): number
    return uint8(band(rshift(insn, 8), 0xff))
end
local function getB(insn: number): number
    return uint8(band(rshift(insn, 16), 0xff))
end
local function getC(insn: number): number
    return uint8(band(rshift(insn, 24), 0xff))
end

local function getD(insn: number): number
    return int16(rshift(insn, 16))
end
local function getE(insn: number): number
    return int24(rshift(insn, 8))
end

local function setOp(insn: number, op: number): number
    return bor(band(insn, 0xffffff00), uint8(op))
end

local function setA(insn: number, a: number): number
    return bor(band(insn, 0xffff00ff), lshift(uint8(a), 8))
end
local function setB(insn: number, b: number): number
    return bor(band(insn, 0xff00ffff), lshift(uint8(b), 16))
end
local function setC(insn: number, c: number): number
    return bor(band(insn, 0x00ffffff), lshift(uint8(c), 24))
end

local function setD(insn: number, d: number): number
    return bor(band(insn, 0x0000ffff), lshift(int16(d), 16))
end
local function setE(insn: number, e: number): number
    return bor(band(insn, 0xffff00ff), lshift(int24(e), 8))
end

local function hasAux(insn: number): boolean
    local op = getOp(insn)
    return INSTRUCTION_ANYAUX_MAP[op] or false
end

local function formatInstruction(instruction: Instruction, constant_list: { Constant }?): string
    local op = instruction.op
    local op_string = tostringOp(instruction.op)
    local result = op_string

    local arg_list: { valid_arg } = {}
    local function pushGenericStub(key: valid_arg)
        arg_list[#arg_list + 1] = key
    end
    local has_args = false
    local function pushGeneric(key: valid_arg)
        has_args = true
        pushGeneric = pushGenericStub
        pushGenericStub(key)
    end

    local function pushA()
        pushGeneric("a")
    end
    local function pushB()
        pushGeneric("b")
    end
    local function pushC()
        pushGeneric("c")
    end
    local function pushD()
        pushGeneric("d")
    end
    local function pushE()
        pushGeneric("e")
    end
    local function pushAUX()
        pushGeneric("aux")
    end

    if INSTRUCTION_SPECIAL_MAP[op] then
        return result
    elseif INSTRUCTION_A_MAP[op] then
        -- local instructiona = instruction :: InstructionA
        -- return result .. "(A" .. instructiona.a .. ")"
        pushA()
    elseif INSTRUCTION_D_MAP[op] then
        -- local instructiond = instruction :: InstructionD
        -- return result .. "(D" .. instructiond.d .. ")"
        pushD()
    elseif INSTRUCTION_E_MAP[op] then
        -- local instructione = instruction :: InstructionE
        -- return result .. "(E" .. instructione.e .. ")"
        pushE()

    elseif INSTRUCTION_AB_MAP[op] then
        -- local instructionab = instruction :: InstructionAB
        -- return result .. "(A" .. instructionab.a .. ", B" .. instructionab.b .. ")"
        pushA()
        pushB()
    elseif INSTRUCTION_AC_MAP[op] then
        -- local instructionac = instruction :: InstructionAC
        -- return result .. "(A" .. instructionac.a .. ", C" .. instructionac.c .. ")"
        pushA()
        pushC()
    elseif INSTRUCTION_AD_MAP[op] then
        -- local instructionad = instruction :: InstructionAD
        -- return result .. "(A" .. instructionad.a .. ", D" .. instructionad.d .. ")"
        pushA()
        pushD()
    elseif INSTRUCTION_AAUX_MAP[op] then
        -- local instructionaaux = instruction :: InstructionAAUX
        -- return result .. "(A" .. instructionaaux.a .. ", AUX" .. instructionaaux.aux .. ")"
        pushA()
        pushAUX()

    elseif INSTRUCTION_ABC_MAP[op] then
        -- local instructionabc = instruction :: InstructionABC
        -- return result .. "(A" .. instructionabc.a .. ", B" .. instructionabc.b .. ", C" .. instructionabc.c .. ")"
        pushA()
        pushB()
        pushC()
    elseif INSTRUCTION_ABAUX_MAP[op] then
        -- local instructionabaux = instruction :: InstructionABAUX
        -- return result .. "(A" .. instructionabaux.a .. ", B" .. instructionabaux.b .. ", AUX" .. instructionabaux.aux .. ")"
        pushA()
        pushB()
        pushAUX()
    elseif INSTRUCTION_ACAUX_MAP[op] then
        -- local instructionacaux = instruction :: InstructionACAUX
        -- return result .. "(A" .. instructionacaux.a .. ", C" .. instructionacaux.c .. ", AUX" .. instructionacaux.aux .. ")"
        pushA()
        pushC()
        pushAUX()
    elseif INSTRUCTION_ADAUX_MAP[op] then
        -- local instructionadaux = instruction :: InstructionADAUX
        -- return result .. "(A" .. instructionadaux.a .. ", D" .. instructionadaux.d .. ", AUX" .. instructionadaux.aux .. ")"
        pushA()
        pushD()
        pushAUX()

    elseif INSTRUCTION_ABCAUX_MAP[op] then
        -- local instructionabcaux = instruction :: InstructionABCAUX
        -- return result .. "(A" .. instructionabcaux.a .. ", B" .. instructionabcaux.b .. ", C" .. instructionabcaux.c .. ", AUX" .. instructionabcaux.aux .. ")"
        pushA()
        pushB()
        pushC()
        pushAUX()
    else
        error("invalid op " .. op_string)
    end

    if has_args then
        result ..= '('
        -- why the FUCK do I have to explicitly put the type here
        for _, arg: valid_arg in arg_list do
            local value = (instruction::any)[arg]
            local function getConstant()
                if not constant_list then
                    return ''
                end

                local value = value
                local op = instruction.op
                if not ARG_CONSTANT_TABLE_MAP[arg][op] then
                    local low24 = CONSTANT_AUX_LOW24BITS[op]
                    if arg ~= "aux" or not low24 or not CONSTANT_AUX_LOWBIT[op] then
                        return ''
                    end

                    if low24 then
                        value = band(value, 0xffffff)
                    else
                        value = band(value, 1)
                    end
                end

                return '(' .. constant_list[value]:format(true) .. ')'
            end
            result ..= arg:upper() .. value .. getConstant() .. ", "
        end
        result = result:sub(1, -3)
        result ..= ')'
    end

    return result
end

local function deserializeInstruction(insn: number, aux: number?): (Instruction, boolean)
    local op = getOp(insn)

    local a = getA(insn)
    local b = getB(insn)
    local c = getC(insn)

    local d = getD(insn)
    local e = getE(insn)

    local op_string = tostringOp(op)
    if INSTRUCTION_ANYAUX_MAP[op] then
        assert(type(aux) == "number", "no aux for op " .. op_string)
    end

    local skip_next = false
    local instruction: any
    local is_nop = (op == LOP_NOP)
    if INSTRUCTION_SPECIAL_MAP[op] then
        instruction = { op = op, is_nop = is_nop, is_break = not is_nop }
    elseif INSTRUCTION_A_MAP[op] then
        instruction = { op = op, a = a }
    elseif INSTRUCTION_D_MAP[op] then
        instruction = { op = op, d = d }
    elseif INSTRUCTION_E_MAP[op] then
        instruction = { op = op, e = e }

    elseif INSTRUCTION_AB_MAP[op] then
        instruction = { op = op, a = a, b = b }
    elseif INSTRUCTION_AC_MAP[op] then
        instruction = { op = op, a = a, c = c }
    elseif INSTRUCTION_AD_MAP[op] then
        instruction = { op = op, a = a, d = d }
    elseif INSTRUCTION_AAUX_MAP[op] then
        skip_next = true
        instruction = { op = op, a = a, aux = aux }

    elseif INSTRUCTION_ABC_MAP[op] then
        instruction = { op = op, a = a, b = b, c = c }
    elseif INSTRUCTION_ABAUX_MAP[op] then
        skip_next = true
        instruction = { op = op, a = a, b = b, aux = aux }
    elseif INSTRUCTION_ACAUX_MAP[op] then
        skip_next = true
        instruction = { op = op, a = a, c = c, aux = aux }
    elseif INSTRUCTION_ADAUX_MAP[op] then
        skip_next = true
        instruction = { op = op, a = a, d = d, aux = aux }

    elseif INSTRUCTION_ABCAUX_MAP[op] then
        skip_next = true
        instruction = { op = op, a = a, b = b, c = c, aux = aux }

    else
        error("invalid op " .. op_string)
    end

    instruction.format = formatInstruction
    instruction.op_string = if BITREADER_DEBUG then op_string else nil

    return instruction, skip_next
end

return {
    enum = enum,
    formatString = formatString,

    LBC_VERSION_MIN = LBC_VERSION_MIN,
    LBC_VERSION_MAX = LBC_VERSION_MAX,

    LBC_TYPE_VERSION_MIN = LBC_TYPE_VERSION_MIN,
    LBC_TYPE_VERSION_MAX = LBC_TYPE_VERSION_MAX,

    LBC_TYPE_TAGGED_USERDATA_BASE = LBC_TYPE_TAGGED_USERDATA_BASE,
    LBC_TYPE_TAGGED_USERDATA_END = LBC_TYPE_TAGGED_USERDATA_END,

    LBC_TYPE_NIL = LBC_TYPE_NIL,
    LBC_TYPE_BOOLEAN = LBC_TYPE_BOOLEAN,
    LBC_TYPE_NUMBER = LBC_TYPE_NUMBER,
    LBC_TYPE_STRING = LBC_TYPE_STRING,
    LBC_TYPE_TABLE = LBC_TYPE_TABLE,
    LBC_TYPE_FUNCTION = LBC_TYPE_FUNCTION,
    LBC_TYPE_THREAD = LBC_TYPE_THREAD,
    LBC_TYPE_USERDATA = LBC_TYPE_USERDATA,
    LBC_TYPE_VECTOR = LBC_TYPE_VECTOR,
    LBC_TYPE_BUFFER = LBC_TYPE_BUFFER,

    LBC_CONSTANT_NIL = LBC_CONSTANT_NIL,
    LBC_CONSTANT_BOOLEAN = LBC_CONSTANT_BOOLEAN,
    LBC_CONSTANT_NUMBER = LBC_CONSTANT_NUMBER,
    LBC_CONSTANT_STRING = LBC_CONSTANT_STRING,
    LBC_CONSTANT_IMPORT = LBC_CONSTANT_IMPORT,
    LBC_CONSTANT_TABLE = LBC_CONSTANT_TABLE,
    LBC_CONSTANT_CLOSURE = LBC_CONSTANT_CLOSURE,
    LBC_CONSTANT_VECTOR = LBC_CONSTANT_VECTOR,

    LBC_CONSTANT_MIN = LBC_CONSTANT_MIN,
    LBC_CONSTANT_MAX = LBC_CONSTANT_MAX,

    Constant = Constant,

    tryToGetProto = tryToGetProto,

    LOP_NOP = LOP_NOP,

    LOP_BREAK = LOP_BREAK,

    LOP_LOADNIL = LOP_LOADNIL,
    LOP_LOADB = LOP_LOADB,
    LOP_LOADN = LOP_LOADN,
    LOP_LOADK = LOP_LOADK,
    LOP_MOVE = LOP_MOVE,

    LOP_GETGLOBAL = LOP_GETGLOBAL,
    LOP_SETGLOBAL = LOP_SETGLOBAL,

    LOP_GETUPVAL = LOP_GETUPVAL,
    LOP_SETUPVAL = LOP_SETUPVAL,
    LOP_CLOSEUPVALS = LOP_CLOSEUPVALS,

    LOP_GETIMPORT = LOP_GETIMPORT,

    LOP_GETTABLE = LOP_GETTABLE,
    LOP_SETTABLE = LOP_SETTABLE,
    LOP_GETTABLEKS = LOP_GETTABLEKS,
    LOP_SETTABLEKS = LOP_SETTABLEKS,
    LOP_GETTABLEN = LOP_GETTABLEN,
    LOP_SETTABLEN = LOP_SETTABLEN,

    LOP_NEWCLOSURE = LOP_NEWCLOSURE,
    LOP_NAMECALL = LOP_NAMECALL,
    LOP_CALL = LOP_CALL,
    LOP_RETURN = LOP_RETURN,

    LOP_JUMP = LOP_JUMP,
    LOP_JUMPBACK = LOP_JUMPBACK,
    LOP_JUMPIF = LOP_JUMPIF,
    LOP_JUMPIFNOT = LOP_JUMPIFNOT,
    LOP_JUMPIFEQ = LOP_JUMPIFEQ,
    LOP_JUMPIFLE = LOP_JUMPIFLE,
    LOP_JUMPIFLT = LOP_JUMPIFLT,
    LOP_JUMPIFNOTEQ = LOP_JUMPIFNOTEQ,
    LOP_JUMPIFNOTLE = LOP_JUMPIFNOTLE,
    LOP_JUMPIFNOTLT = LOP_JUMPIFNOTLT,

    LOP_ADD = LOP_ADD,
    LOP_SUB = LOP_SUB,
    LOP_MUL = LOP_MUL,
    LOP_DIV = LOP_DIV,
    LOP_MOD = LOP_MOD,
    LOP_POW = LOP_POW,

    LOP_ADDK = LOP_ADDK,
    LOP_SUBK = LOP_SUBK,
    LOP_MULK = LOP_MULK,
    LOP_DIVK = LOP_DIVK,
    LOP_MODK = LOP_MODK,
    LOP_POWK = LOP_POWK,

    LOP_AND = LOP_AND,
    LOP_OR = LOP_OR,
    LOP_ANDK = LOP_ANDK,
    LOP_ORK = LOP_ORK,
    LOP_CONCAT = LOP_CONCAT,

    LOP_NOT = LOP_NOT,
    LOP_MINUS = LOP_MINUS,
    LOP_LENGTH = LOP_LENGTH,

    LOP_NEWTABLE = LOP_NEWTABLE,
    LOP_DUPTABLE = LOP_DUPTABLE,
    LOP_SETLIST = LOP_SETLIST,

    LOP_FORNPREP = LOP_FORNPREP,
    LOP_FORNLOOP = LOP_FORNLOOP,
    LOP_FORGLOOP = LOP_FORGLOOP,
    LOP_FORGPREP_INEXT = LOP_FORGPREP_INEXT,

    LOP_FASTCALL3 = LOP_FASTCALL3,
    LOP_FORGPREP_NEXT = LOP_FORGPREP_NEXT,

    LOP_NATIVECALL = LOP_NATIVECALL,

    LOP_GETVARARGS = LOP_GETVARARGS,

    LOP_DUPCLOSURE = LOP_DUPCLOSURE,

    LOP_PREPVARARGS = LOP_PREPVARARGS,

    LOP_LOADKX = LOP_LOADKX,

    LOP_JUMPX = LOP_JUMPX,

    LOP_FASTCALL = LOP_FASTCALL,

    LOP_COVERAGE = LOP_COVERAGE,

    LOP_CAPTURE = LOP_CAPTURE,

    LOP_SUBRK = LOP_SUBRK,
    LOP_DIVRK = LOP_DIVRK,

    LOP_FASTCALL1 = LOP_FASTCALL1,
    LOP_FASTCALL2 = LOP_FASTCALL2,
    LOP_FASTCALL2K = LOP_FASTCALL2K,

    LOP_FORGPREP = LOP_FORGPREP,

    LOP_JUMPXEQKNIL = LOP_JUMPXEQKNIL,
    LOP_JUMPXEQKB = LOP_JUMPXEQKB,
    LOP_JUMPXEQKN = LOP_JUMPXEQKN,
    LOP_JUMPXEQKS = LOP_JUMPXEQKS,

    LOP_IDIV = LOP_IDIV,
    LOP_IDIVK = LOP_IDIVK,

    LOP__COUNT = LOP__COUNT,

    tostringOp = tostringOp,

    getOp = getOp,
    getA = getA,
    getB = getB,
    getC = getC,
    getD = getD,
    getE = getE,

    setOp = setOp,
    setA = setA,
    setB = setB,
    setC = setC,
    setD = setD,
    setE = setE,

    haxAux = hasAux,

    deserializeInstruction = deserializeInstruction,
}