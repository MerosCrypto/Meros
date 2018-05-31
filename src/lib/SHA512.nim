#Wrapper for the SHA512 C library

#C function
proc cSHA512(hexData: cstring): cstring {.header: "../../src/lib/SHA512/SHA512.h", importc: "sha512".}
#Take in a hex string, return the hex string of the SHA512 hash
proc SHA512*(hex: string): string =
    result = $cSHA512(hex)
