#Errors lib.
import ../Errors

#Util lib.
import ../Util

#Hash master type.
import HashCommon

#nimcrypto lib.
import nimcrypto

#Define the Hash Types.
type
    Blake2_256Hash* = HashCommon.Hash[256]
    Blake2_512Hash* = HashCommon.Hash[512]

#C API which is used solely for Blake2b-64.
const currentFolder: string = currentSourcePath().substr(0, currentSourcePath().len - 11)
#We don't compile in Blake2b as it's already compiled in elsewhere.
#{.compile: currentFolder & "Blake2/blake2b-ref.c".}

{.passC: "-I" & currentFolder & "Blake2/"}
{.push, header: "blake2.h".}
type Blake2bState {.importc: "blake2b_state".} = object
proc init(
    state: ptr Blake2bState,
    bytes: int
): cint {.importc: "blake2b_init".}
proc update(
    state: ptr Blake2bState,
    data: pointer,
    len: int
): cint {.importc: "blake2b_update".}
proc finalize(
    state: ptr Blake2bState,
    output: pointer,
    len: int
): cint {.importc: "blake2b_final".}
{.pop.}

#Blake 64 hashing algorithm.
proc Blake2_64*(
    bytesArg: string
): uint64 {.forceCheck: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #Allocate the State.
    var state: ptr Blake2bState = cast[ptr Blake2bState](alloc0(sizeof(Blake2bState)))

    #Hash the bytes.
    if state.init(8) != 0:
        panic("Failed to init a Blake2b State.")
    if state.update(addr bytes[0], bytes.len) != 0:
        panic("Failed to update a Blake2b State.")

    #Save the result.
    var hash: string = newString(8)
    if state.finalize(addr hash[0], 8) != 0:
        panic("Failed to finalize a Blake2b State.")
    result = uint64(hash.fromBinary())

    #Deallocate the state.
    dealloc(state)

#Blake 256 hashing algorithm.
proc Blake2_256*(
    bytesArg: string
): Blake2_256Hash {.forceCheck: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg
    if bytes.len == 0:
        bytes = $char(0)

    #Allocate the State.
    var state: ptr Blake2bState = cast[ptr Blake2bState](alloc0(sizeof(Blake2bState)))

    #Hash the bytes.
    if state.init(32) != 0:
        panic("Failed to init a Blake2b State.")
    if state.update(addr bytes[0], bytesArg.len) != 0:
        panic("Failed to update a Blake2b State.")

    #Save the result.
    if state.finalize(addr result.data[0], 32) != 0:
        panic("Failed to finalize a Blake2b State.")

    #Deallocate the state.
    dealloc(state)

#Blake 512 hashing algorithm.
proc Blake2_512*(
    bytesArg: string
): Blake2_512Hash {.forceCheck: [].} =
    #Copy the bytes argument.
    var bytes: string = bytesArg

    #If it's an empty string...
    if bytes.len == 0:
        return Blake2_512Hash(
            data: blake2_512.digest(EmptyHash, uint(bytes.len)).data
        )

    #Digest the byte array.
    result.data = blake2_512.digest(cast[ptr uint8](addr bytes[0]), uint(bytes.len)).data

#String to Blake2_256Hash.
proc toBlake2_256Hash*(
    hash: string
): Blake2_256Hash {.forceCheck: [
    ValueError
].} =
    try:
        result = hash.toHash(256)
    except ValueError as e:
        raise e

#String to Blake2_512Hash.
proc toBlake2_512Hash*(
    hash: string
): Blake2_512Hash {.forceCheck: [
    ValueError
].} =
    try:
        result = hash.toHash(512)
    except ValueError as e:
        raise e
