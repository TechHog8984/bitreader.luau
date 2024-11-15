-- last checked luau version: 0.635

local LOGGING = false
local log = if LOGGING then print else function(...) end

local bitreader = require("bitreader")

local table_create = table.create

local rshift = bit32.rshift
local band = bit32.band
local bnot = bit32.bnot

local enum do
    local highest = 0
    enum = function(explicit)
        if explicit then
            highest = explicit - 1
        end
        highest += 1
        return highest
    end
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

local Constant = {}
Constant.__index = Constant

function Constant.new(t: number, value: any?, secondary: any?)
    assert(t >= LBC_CONSTANT_NIL and t <= LBC_CONSTANT_VECTOR, "constant type " .. t .. " is out of range (" .. LBC_CONSTANT_MIN .. ".." .. LBC_CONSTANT_MAX .. ')')

    local constant = {
        t = t,
        [
            if t == LBC_CONSTANT_NIL then ""
            elseif t == LBC_CONSTANT_BOOLEAN then "bool"
            elseif t == LBC_CONSTANT_NUMBER then "number"
            elseif t == LBC_CONSTANT_STRING then "string"
            elseif t == LBC_CONSTANT_IMPORT then "import"
            elseif t == LBC_CONSTANT_TABLE then "table"
            elseif t == LBC_CONSTANT_CLOSURE then "closure"
            elseif t == LBC_CONSTANT_VECTOR then "vector"
            else error("INVALID CONSTANT TYPE " .. t)
        ] = value,
    }

    if secondary then
        constant[
            if t == LBC_CONSTANT_IMPORT then "value"
            else error("INVALID CONSTANT TYPE FOR SECONDARY")
        ] = secondary
    end

    return constant
end

local genv = getfenv()
local function deserialize(bytecode: string | buffer)
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
        return
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
        local proto = {
            bytecode_id = i - 1,

            max_stack_size = reader:readu8(),
            num_params = reader:readu8(),
            num_upvalues = reader:readu8(),
            is_vararg = reader:readu8() ~= 0
        }
        log("  max_stack_size: " .. proto.max_stack_size)
        log("  num_params: " .. proto.num_params)
        log("  num_upvalues: " .. proto.num_upvalues)
        log("  is_vararg: " .. tostring(proto.is_vararg))

        if lbc_version >= 4 then
            proto.flags = reader:readu8()
            log("  flags: " .. proto.flags)

            if types_version == 1 or types_version == 2 or types_version == 3 then
                local type_size = reader:readvarint()
                log("  type_size: " .. type_size)
            end
        end

        local size_code = reader:readvarint()
        proto.code = table_create(size_code)
        proto.size_code = size_code

        log("  size_code: " .. size_code)

        for j = 1, size_code do
            proto.code[j - 1] = reader:readu32()
        end

        log("  code: ", proto.code)

        local constant_count = reader:readvarint()
        proto.constant_list = table_create(constant_count)
        proto.constant_count = constant_count

        log("  constant_count: " .. constant_count)

        for j = 1, constant_count do
            local value, secondary
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

                value = proto.constant_list[id0].string
                secondary = genv[proto.constant_list[id0].string]
                for i = 2, count do
                    value = value .. '.' .. proto.constant_list[id1].string
                    secondary = secondary[proto.constant_list[id1].string]
                    id1 = id2
                end
            elseif t == LBC_CONSTANT_TABLE then
                local key_count = reader:readvarint()
                value = {}
                for i = 1, key_count do
                    local key = reader:readvarint()
                    value[proto.constant_list[key].string] = 0
                end
            elseif t == LBC_CONSTANT_CLOSURE then
                -- TODO: constant closure
                value = proto_list[reader:readvarint()]
            elseif t == LBC_CONSTANT_VECTOR then
                value = {
                    x = reader:readf32(),
                    y = reader:readf32(),
                    z = reader:readf32(),
                    w = reader:readf32()
                }
            else
                error("unexpected constant kind " .. t)
            end
            proto.constant_list[j - 1] = Constant.new(t, value, secondary)
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

        local line_info = reader:readu8()
        if line_info ~= 0 then
            proto.line_gap_log2 = reader:readu8()

            local intervals = rshift(proto.size_code - 1, proto.line_gap_log2) + 1
            local abs_offset = band(proto.size_code + 3, bnot(3))

            local line_info_count = abs_offset + intervals * 4
            proto.line_info = table_create(line_info_count)
            proto.line_info_count = line_info_count
            proto.line_info_abs_offset = abs_offset

            local last_offset = 0
            for j = 1, proto.size_code do
                last_offset += reader:readu8()
                proto.line_info[j - 1] = last_offset
            end

            local last_line = 0
            for j = 1, intervals do
                last_line += reader:readi32()
                proto.line_info[j - 1 + proto.size_code] = last_line
            end
        end

        local debug_info = reader:readu8()
        if debug_info ~= 0 then
            local loc_var_count = reader:readvarint()
            proto.loc_var_list = table_create(loc_var_count)
            proto.loc_var_count = loc_var_count

            for j = 1, loc_var_count do
                proto.loc_var_list[j - 1] = {
                    var_name = readString(),
                    start_pc = reader:readvarint(),
                    end_pc = reader:readvarint(),
                    reg = reader:readu8()
                }
            end

            local upvalue_count = reader:readvarint()
            assert(upvalue_count == proto.num_upvalues)

            proto.upvalues = table_create(upvalue_count)
            proto.upvalue_count = upvalue_count

            for j = 1, upvalue_count do
                proto.upvalues[j - 1] = readString()
            end
        end

        proto_list[i - 1] = proto
    end

    local main_id = reader:readvarint()
    local main = proto_list[main_id]

    return main
end

return deserialize
