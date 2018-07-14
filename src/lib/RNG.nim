#Import the nimcrypto library.
import nimcrypto

#Provide a wrapper for it's randomBytes function.
proc random*(arr: ptr array[0, uint8], length: int) {.raises: [].} =
    discard randomBytes(arr, length)
