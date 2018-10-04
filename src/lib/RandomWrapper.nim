#Errors lib.
import Errors

#Import the nimcrypto library.
import nimcrypto/sysrand

#Provide a wrapper for it's randomBytes function.
proc random*(arr: ptr uint8, length: int) {.raises: [RandomError].} =
    try:
        if randomBytes(arr, length) != length:
            raise newException(RandomError, "The returned random bytes inequals the amount asked for.")
    except Exception:
        raise newException(RandomError, "randomBytes threw an Exception.")
