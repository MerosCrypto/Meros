import nimcrypto

proc random*(arr: ptr array[0, uint8], length: int) =
    discard randomBytes(arr, length)
