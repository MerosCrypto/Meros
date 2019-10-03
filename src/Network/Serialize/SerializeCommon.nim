#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util
export Util

#Lengths of various data types and messages.
const
    BYTE_LEN*:           int = 1
    NICKNAME_LEN*:       int = 2
    INT_LEN*:            int = 4
    MEROS_LEN*:          int = 8
    HASH_LEN*:           int = 48

    ED_PUBLIC_KEY_LEN*:  int = 32
    ED_SIGNATURE_LEN*:   int = 64
    BLS_PUBLIC_KEY_LEN*: int = 48
    BLS_SIGNATURE_LEN*:  int = 96

    DIFFICULTY_LEN*: int = INT_LEN + INT_LEN + HASH_LEN

    BLOCK_HEADER_LENS*: array[2, int] = [
        INT_LEN + HASH_LEN + HASH_LEN + HASH_LEN + BYTE_LEN,
        INT_LEN + INT_LEN + BLS_SIGNATURE_LEN
    ]

    VERIFICATION_PREFIX*:        int = 0
    VERIFICATION_PACKET_PREFIX*: int = 1
    SEND_DIFFICULTY_PREFIX*:     int = 2
    DATA_DIFFICULTY_PREFIX*:     int = 3
    GAS_PRICE_PREFIX*:           int = 4
    MERIT_REMOVAL_PREFIX*:       int = 5

    VERIFICATION_LEN*: int = NICKNAME_LEN + HASH_LEN

    VERIFICATION_PACKET_LENS*: array[3, int] = [
        BYTE_LEN,
        NICKNAME_LEN,
        HASH_LEN
    ]

    MERIT_REMOVAL_VERIFICATION_PACKET_LENS*: array[3, int] = [
        BYTE_LEN,
        BLS_PUBLIC_KEY_LEN,
        HASH_LEN
    ]

    MERIT_REMOVAL_LENS*: array[2, int] = [
        NICKNAME_LEN + BYTE_LEN + BYTE_LEN,
        BYTE_LEN
    ]

    CLAIM_LENS*: array[3, int] = [
        BYTE_LEN,
        HASH_LEN,
        ED_PUBLIC_KEY_LEN + BLS_SIGNATURE_LEN
    ]

    SEND_LENS*: array[5, int] = [
        BYTE_LEN,
        HASH_LEN + BYTE_LEN,
        BYTE_LEN,
        ED_PUBLIC_KEY_LEN + MEROS_LEN,
        ED_SIGNATURE_LEN + INT_LEN
    ]

    DATA_LENS*: array[2, int] = [
        HASH_LEN + BYTE_LEN,
        ED_SIGNATURE_LEN + INT_LEN
    ]

#Deseralizes a string by getting the length of the next set of bytes, slicing that out, and moving on.
func deserialize*(
    data: string,
    lengths: varargs[int]
): seq[string] {.forceCheck: [].} =
    #Allocate the seq.
    result = newSeq[string](lengths.len)

    #Iterate over every length, slicing the strings out.
    var handled: int = 0
    for i in 0 ..< lengths.len:
        result[i] = data.substr(handled, handled + lengths[i] - 1)
        handled += lengths[i]

#Turns a seq[string] backed into a serialized string, only using the first X items.
#Used for hash calculation when parsing objects.
func reserialize*(
    data: seq[string],
    start: int,
    endIndex: int
): string {.forceCheck: [].} =
    for i in start .. endIndex:
        result &= data[i]
