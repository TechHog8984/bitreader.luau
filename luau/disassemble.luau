--!strict

--[[
    luau/disassemble.luau
    part of https://github.com/TechHog8984/bitreader.luau
    by techhog
    see LICENSE

    target luau version: 0.635
]]

local log: (...any) -> () = if BITREADER_DEBUG then print else function(...) end

local deserialize = require("deserialize")
local common = require("common")

local tryToGetProto = common.tryToGetProto

type Proto = common.Proto

local function disassembleProto(proto: Proto): string
    log("proto", proto)

    local result = ""

    -- header
    result ..= "-- proto id: " .. proto.bytecode_id
    local function addToHeader(key: string)
        result ..= ", " .. key .. ": " .. tostring(proto[key])
    end

    addToHeader("max_stack_size")
    addToHeader("num_params")
    addToHeader("num_upvalues")
    addToHeader("is_vararg")
    if proto.flags then addToHeader("flags") end
    addToHeader("line_defined")
    if proto.debug_name and #proto.debug_name > 0 then addToHeader("debug_name") else
        result ..= ", debug_name: (no debug_name)" end

    result ..= '\n'

    result ..= "-- instructions:\n"
    for index = 0, proto.size_instructions - 1 do
        result ..= index .. '\t' .. proto.instructions[index]:format(proto.constant_list) .. '\n'
    end

    result ..= "-- constants:\n"
    if proto.constant_count == 0 then
        result ..= "(no constants)\n"
    else
        for index = 0, proto.constant_count - 1 do
            result ..= index .. '\t' .. proto.constant_list[index]:format() .. '\n'
        end
    end

    -- result ..= "-- line_info:\n"
    -- if proto.line_info and proto.line_info_count then
    --     for index = 0, proto.line_info_count - 1 do
    --         result ..= index .. '\t' .. tostring(proto.line_info[index]) .. '\n'
    --     end
    -- else
    --     result ..= "(no line_info)\n"
    -- end

    result ..= "-- protos:\n"
    if proto.proto_count == 0 then
        result ..= "(no protos)\n"
    else
        for index = 0, proto.proto_count - 1 do
            result ..= disassembleProto(proto.proto_list[index]) .. '\n'
        end
    end

    return result
end
local function disassemble(arg1: string | Proto): string
    local proto = tryToGetProto(arg1, deserialize)
    assert(proto)

    return disassembleProto(proto)
end

return disassemble