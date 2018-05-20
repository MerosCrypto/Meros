proc cSHA512(hexData: cstring): cstring {.header: "../lib/c/SHA512.h", importc: "sha512".}
proc SHA512*(hex: string): string =
    result = $cSHA512(hex)
