#Import the nimcrypto library.
import nimcrypto/sysrand

#Provide a wrapper for it's randomBytes function.
proc random*(arr: ptr array[0, uint8], length: int) {.raises: [Exception].} =
    discard randomBytes(arr, length)
