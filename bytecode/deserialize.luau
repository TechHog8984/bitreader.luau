--!strict

--[[
    bytecode/deserialize.luau
    part of https://github.com/TechHog8984/bitreader.luau
    by techhog
    see LICENSE

    target luau version: 0.635
]]

local log: (...any) -> () = if BITREADER_DEBUG then print else function(...) end

local bitreader = require("../bitreader")
local common = require("common")

local table_create = table.create

local rshift = bit32.rshift
local band = bit32.band
local bnot = bit32.bnot

type Closure = common.Closure
type Vector = common.Vector
type Constant = common.Constant
type ConstantString = common.ConstantString
type Proto = common.Proto
type Instruction = common.Instruction

type string_to_number = {
    [string]: number
}

local LBC_VERSION_MIN = common.LBC_VERSION_MIN
local LBC_VERSION_MAX = common.LBC_VERSION_MAX

local LBC_TYPE_VERSION_MIN = common.LBC_TYPE_VERSION_MIN
local LBC_TYPE_VERSION_MAX = common.LBC_TYPE_VERSION_MAX

local LBC_TYPE_TAGGED_USERDATA_BASE = common.LBC_TYPE_TAGGED_USERDATA_BASE
local LBC_TYPE_TAGGED_USERDATA_END = common.LBC_TYPE_TAGGED_USERDATA_END

local LBC_CONSTANT_NIL = common.LBC_CONSTANT_NIL
local LBC_CONSTANT_BOOLEAN = common.LBC_CONSTANT_BOOLEAN
local LBC_CONSTANT_NUMBER = common.LBC_CONSTANT_NUMBER
local LBC_CONSTANT_STRING = common.LBC_CONSTANT_STRING
local LBC_CONSTANT_IMPORT = common.LBC_CONSTANT_IMPORT
local LBC_CONSTANT_TABLE = common.LBC_CONSTANT_TABLE
local LBC_CONSTANT_CLOSURE = common.LBC_CONSTANT_CLOSURE
local LBC_CONSTANT_VECTOR = common.LBC_CONSTANT_VECTOR

local Constant = common.Constant

local hasAux = common.haxAux
local decodeInstruction = common.decodeInstruction

local genv = getfenv()
local function deserialize(bytecode: string | buffer): Proto
    local reader = if type(bytecode) == "string" then bitreader.fromstring(bytecode) else bitreader.frombuffer(bytecode)

    -- for testing error:
    -- local a = buffer.fromstring("_syntax error trol")
    -- buffer.writeu8(a, 0, 0)
    -- reader = bitreader.frombuffer(a)

    local lbc_version = reader:readu8()

    if lbc_version == 0 then
        error("bytecode contains an error! " .. reader:tostring())
    end
    log("lbc_version: " .. lbc_version)

    if lbc_version < LBC_VERSION_MIN or lbc_version > LBC_VERSION_MAX then
        error("bytecode version mismatch (expected [" .. LBC_VERSION_MIN .. ".." .. LBC_VERSION_MAX .. "]; got " .. lbc_version .. ')')
    end

    local types_version = 0
    if lbc_version > 4 then
        types_version = reader:readu8()
        if types_version < LBC_TYPE_VERSION_MIN or types_version > LBC_TYPE_VERSION_MAX then
            error("bytecode type version mismatch (expected [" .. LBC_TYPE_VERSION_MIN .. ".." .. LBC_TYPE_VERSION_MAX .. "]; got " .. types_version .. ')')
        end
    end
    log("types_version: " .. types_version)

    -- string list
    local string_count = reader:readvarint()
    local string_list = table_create(string_count)

    log("string_count: " .. string_count)

    for i = 1, string_count do
        string_list[i - 1] = reader:readstring()
    end
    log("strings:", string_list)

    local function readString()
        local id = reader:readvarint()
        return if id == 0 then "" else string_list[id - 1]
    end

    -- userdata type remapping table
    local userdata_type_limit = LBC_TYPE_TAGGED_USERDATA_END - LBC_TYPE_TAGGED_USERDATA_BASE
    -- local userdata_remapping = table_create(userdata_type_limit, LBC_TYPE_USERDATA)

    if types_version == 3 then
        local index = reader:readu8()

        while index ~= 0 do
            -- local name = readString()
            readString()

            local i = index - 1
            if i > 0 and i < userdata_type_limit then
                -- stuff
            end

            index = reader:readu8()
        end
    end

    -- proto list
    local proto_count = reader:readvarint()
    local proto_list = table_create(proto_count)

    log("proto_count: " .. proto_count)

    for i = 1, proto_count do
        log("proto " .. i - 1)
        local proto: Proto = {
            bytecode_id = i - 1,

            max_stack_size = reader:readu8(),
            num_params = reader:readu8(),
            num_upvalues = reader:readu8(),
            is_vararg = reader:readu8() ~= 0,

            flags = nil,
            instructions = {},
            size_instructions = 0,

            constant_list = {},
            constant_count = 0,

            proto_list = {},
            proto_count = 0,
            line_defined = 0,
            debug_name = "",
        }
        log("  max_stack_size: " .. proto.max_stack_size)
        log("  num_params: " .. proto.num_params)
        log("  num_upvalues: " .. proto.num_upvalues)
        log("  is_vararg: " .. tostring(proto.is_vararg))

        if lbc_version >= 4 then
            proto.flags = reader:readu8()
            log("  flags: " .. proto.flags :: number)

            if types_version == 1 or types_version == 2 or types_version == 3 then
                local type_size = reader:readvarint()
                log("  type_size: " .. type_size)
            end
        end

        local size_code = reader:readvarint()
        proto.instructions = table_create(size_code)

        log("  size_code: " .. size_code)

        do
            local index = 0
            local j = 1
            while j <= size_code do
                local insn = reader:readu32()
                local instruction, skip_next = decodeInstruction(insn, if hasAux(insn) then reader:readu32() else nil)
                proto.instructions[index] = instruction
                if skip_next then
                    j += 1
                end
                index += 1
                j += 1
            end
            proto.size_instructions = index + 1
        end

        log("  size_instructions: " .. proto.size_instructions)
        log("  instructions:", proto.instructions)

        local constant_count = reader:readvarint()
        proto.constant_list = table_create(constant_count)
        proto.constant_count = constant_count

        log("  constant_count: " .. constant_count)

        for j = 1, constant_count do
            local value: nil | boolean | number | string | string_to_number | Closure | Vector
            local t = reader:readu8()
            if t == LBC_CONSTANT_NIL then
                value = nil
            elseif t == LBC_CONSTANT_BOOLEAN then
                value = reader:readu8() ~= 0
            elseif t == LBC_CONSTANT_NUMBER then
                value = reader:readf64()
            elseif t == LBC_CONSTANT_STRING then
                value = readString()
            elseif t == LBC_CONSTANT_IMPORT then
                local iid = reader:readu32()

                local count = rshift(iid, 30)
                assert(count > 0)

                local id0 = band(rshift(iid, 20), 1023)
                local id1 = band(rshift(iid, 10), 1023)
                local id2 = band(iid, 1023)

                local const = proto.constant_list[id0]::ConstantString
                local values: string = const.string

                local id = id1
                for i = 2, count do
                    const = proto.constant_list[id]::ConstantString
                    local str = const.string
                    values = values .. '.' .. str
                    id = id2
                end

                value = values
            elseif t == LBC_CONSTANT_TABLE then
                local key_count = reader:readvarint()
                local valuet: string_to_number = {}

                for i = 1, key_count do
                    local id = reader:readvarint()
                    local const = proto.constant_list[id]::ConstantString
                    valuet[const.string] = 0
                end

                value = valuet
            elseif t == LBC_CONSTANT_CLOSURE then
                -- TODO: better constant closures
                value = { proto = proto_list[reader:readvarint()] } :: Closure
            elseif t == LBC_CONSTANT_VECTOR then
                value = {
                    x = reader:readf32(),
                    y = reader:readf32(),
                    z = reader:readf32(),
                    w = reader:readf32(),
                }
            else
                error("unexpected constant kind " .. t)
            end
            proto.constant_list[j - 1] = Constant.new(t, value)
        end

        log("  constants:", proto.constant_list)

        local child_proto_count = reader:readvarint()
        proto.proto_list = table_create(proto_count)
        proto.proto_count = child_proto_count

        log("  child_proto_count: " .. child_proto_count)

        for j = 1, child_proto_count do
            local fid = reader:readvarint()
            log("    fid: " .. fid)
            proto.proto_list[j - 1] = proto_list[fid]
        end

        proto.line_defined = reader:readvarint()
        proto.debug_name = readString()

        log("  line_defined: " .. proto.line_defined)
        log("  debug_name: " .. proto.debug_name)

        if reader:readu8() ~= 0 then -- line_info
            local line_gap_log2 = reader:readu8()

            local intervals = rshift(size_code - 1, line_gap_log2) + 1
            local abs_offset = band(size_code + 3, bnot(3))

            local line_info_count = abs_offset + intervals * 4
            local line_info = table_create(line_info_count)

            proto.line_gap_log2 = line_gap_log2
            proto.line_info = line_info
            proto.line_info_count = line_info_count
            proto.line_info_abs_offset = abs_offset

            log("  line_info_count: " .. line_info_count)

            local last_offset = 0
            for j = 1, size_code do
                last_offset += reader:readu8()
                line_info[j - 1] = last_offset
            end

            local last_line = 0
            for j = 1, intervals do
                last_line += reader:readi32()
                line_info[j - 1 + size_code] = last_line
            end

            log("  line_info:", line_info)
        end

        if reader:readu8() ~= 0 then -- debug_info
            local loc_var_count = reader:readvarint()
            local loc_var_list = table_create(loc_var_count)

            proto.loc_var_list = loc_var_list
            proto.loc_var_count = loc_var_count

            log("  loc_var_count: " .. loc_var_count)

            for j = 1, loc_var_count do
                loc_var_list[j - 1] = {
                    var_name = readString(),
                    start_pc = reader:readvarint(),
                    end_pc = reader:readvarint(),
                    reg = reader:readu8()
                }
            end

            log("  loc_var_list:", loc_var_list)

            local upvalue_count = reader:readvarint()
            assert(upvalue_count == proto.num_upvalues)

            local upvalue_list = table_create(upvalue_count)

            proto.upvalue_list = upvalue_list
            proto.upvalue_count = upvalue_count

            for j = 1, upvalue_count do
                upvalue_list[j - 1] = readString()
            end

            log("  upvalue_list:", upvalue_list)
        end

        proto_list[i - 1] = proto
    end

    local main_id = reader:readvarint()
    local main = proto_list[main_id]

    return main
end

return deserialize
