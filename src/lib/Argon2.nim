#Wrapper for the Argon2 C library that won the PHC competition.

#Compile the relevant C file.
{.compile: "Argon2/argon2.c".}

#C function.
proc argon2d(
    iterations: uint32,
    memory: uint32,
    parallelism: uint32,
    data: ptr uint32,
    dataLen: uint32,
    salt: ptr uint32,
    saltLen: uint32,
    res: ptr uint32,
    resLen: uint32
) {.header: "../../src/lib/Argon2/argon2.h", importc: "argon2d_hash_raw".}

#Take in data and a salt, return a 64 character string.
proc Argon2*(dataArg: string, saltArg: string): string {.raises: [].} =
    var
        data: string = dataArg
        salt: string = saltArg
        resTemp: array[32, uint32]
        res: string

    #Iterate 10 times, using 200MB, with no parallelism.
    argon2d(
        (uint32) 10,
        (uint32) 18,
        (uint32) 1,
        cast[ptr uint32](addr data[0]),
        (uint32) data.len,
        cast[ptr uint32](addr salt[0]),
        (uint32) salt.len,
        addr resTemp[0],
        (uint32) 32
    )

    result =  $resTemp
