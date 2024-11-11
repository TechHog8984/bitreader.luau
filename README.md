# bitreader.luau
A read-only wrapper for luau buffers

## Why use bitreader?
* bitreader keeps track of its offset
* bitreader has a readvarint function for luau bytecode (as well as a [deserializer](bytecode.luau))

## Usage
Create a bitreader with `bitreader.frombuffer` or `bitreader.fromstring`:
```lua
bitreader.frombuffer(data: buffer, string_len_func: ((...any) -> ...any)?) : bitreader
bitreader.fromstring(data: string, string_len_func: ((...any) -> ...any)?) : bitreader
```
`string_len_func` is optional and will be used to get the string's length in `bitreader:readstring` (if the length argument is omitted)

its default is `bitreader:readvarint`

### Methods
Bitreader wraps all buffer read methods as well as `tostring` and `len`.

See https://create.roblox.com/docs/reference/engine/libraries/buffer for more info

* `bitreader:readvarint` reads an integer of varying size (see [luau/BytecodeBuilder.cpp](https://github.com/luau-lang/luau/blob/master/Compiler/src/BytecodeBuilder.cpp)'s writeVarInt and [luau/lvmload.cpp](https://github.com/luau-lang/luau/blob/master/VM/src/lvmload.cpp)'s readVarInt)
```lua
bitreader:readvarint(): number
```

* `bitreader:readstring` reads a string that is a certain length. If there is no length argument, `string_len_func` will be called (see [Usage](#usage))
```lua
bitreader:readstring(length: number?): number
```
