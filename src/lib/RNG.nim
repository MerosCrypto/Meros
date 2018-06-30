when defined(windows):
    import winlean

    {.push, stdcall, dynlib: "Advapi32.dll".}
    proc CryptAcquireContext(
        prov: ptr int,
        ignored1: WideCString,
        ignored2: WideCString,
        provType: uint32,
        provFlags: uint32
    ): WinBool {.importc: "CryptAcquireContextW".}

    proc CryptGenRandom(
        hProv: int,
        dwLen: uint32,
        pbBuffer: pointer
    ): WinBool {.importc: "CryptGenRandom".}
    {.pop.}

    var prov: int
    if CryptAcquireContext(addr prov, nil, nil, 1'u32, 4026531840'u32) == 0:
        raise newException(Exception, "Couldn't acquire a cryptographic context")

    proc randbytes(quantity: int): seq[char] =
        result = newSeq[char](quantity)
        for i in 0 ..< quantity:
            if CryptGenRandom(prov, 8'u32, addr result[i]) == 0:
                raise newException(Exception, "Couldn't get a random byte")
else:
    proc randbytes(quantity: int): seq[char] =
        result = newSeq[char](quantity)
        
        var urandom: File = open("/dev/urandom")
        discard urandom.readChars(result, 0, quantity)
        urandom.close()

proc random*(quantity: int): seq[uint8] =
    result = newSeq[uint8](quantity)
    var bytes: seq[char] = randbytes(quantity)
    for i in 0 ..< quantity:
        result[i] = (uint8) bytes[i]
