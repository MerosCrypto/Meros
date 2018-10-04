#Wrapper for the Argon2 C library that won the PHC competition.

#Errors lib.
import ../Errors

#Util lib for padding strings.
import ../Util

#Hash master type.
import HashCommon

#String utils standard lib.
import strutils

#Define the Hash Types.
type ArgonHash* = Hash[512]

#Include the headers.
{.passC: "-Isrc/lib/Hash/Argon/include".}
{.passC: "-Isrc/lib/Hash/Argon/src".}
{.passC: "-Isrc/lib/Hash/Argon/src/blake2".}
#Compile the relevant C files.
{.compile: "Argon/src/core.c".}
{.compile: "Argon/src/thread.c".}
{.compile: "Argon/src/encoding.c".}
{.compile: "Argon/src/blake2/blake2b.c".}
{.compile: "Argon/src/ref.c".}
{.compile: "Argon/src/argon2.c".}

#C function.
proc argon2d(
    iterations: uint32,
    memory: uint32,
    parallelism: uint32,
    data: ptr uint8,
    dataLen: uint32,
    salt: ptr uint8,
    saltLen: uint32,
    res: ptr uint8,
    resLen: uint32
): cint {.
    header: "../../src/lib/Hash/Argon/include/argon2.h",
    importc: "argon2d_hash_raw"
.}

#Take in data (128 char max) and a salt (128 char max); return a ArgonHash.
proc Argon*(
    dataArg: string,
    saltArg: string,
    reduced: bool = false
): ArgonHash {.raises: [ArgonError, ValueError].} =
    var
        data: string = dataArg.pad(128, $char(0))
        salt: string = saltArg.pad(128, $char(0))

    #Verify argument validity.
    if (data.len > 128) or (salt.len > 128):
        raise newException(ValueError, "Invalid data/salt length.")

    var
        iterations: uint32
        memory: uint32
    if not reduced:
        #Iterate 10000 times, using 200MB, with no parallelism.
        iterations = 10000
        memory = 18
    else:
        #Iterate 1 times, using 256KB, with no parallelism.
        iterations = 1
        memory = 8

    #The iteration quantity and memory usage values are for testing only.
    #They are not final and will be changed.
    if argon2d(
        iterations,
        memory,
        uint32(1),
        cast[ptr uint8](addr data[0]),
        uint32(128),
        cast[ptr uint8](addr salt[0]),
        uint32(128),
        addr result.data[0],
        uint32(64)
    ) != 0:
        raise newException(ArgonError, "Argon2d raised an error.")

#String to ArgonHash.
proc toArgonHash*(hash: string): ArgonHash {.raises: [ValueError].} =
    hash.toHash(512)
