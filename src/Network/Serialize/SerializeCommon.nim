#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Lengths of various data types and messages.
const
    BYTE_LEN*:           int = 1
    INT_LEN*:            int = 4
    MEROS_LEN*:          int = 8
    HASH_LEN*:           int = 48
    PUBLIC_KEY_LEN*:     int = 32
    SIGNATURE_LEN*:      int = 64
    BLS_PUBLIC_KEY_LEN*: int = 48
    BLS_SIGNATURE_LEN*:  int = 96

    VERIFICATION_LEN*:        int = BLS_PUBLIC_KEY_LEN + INT_LEN + HASH_LEN
    MEMORY_VERIFICATION_LEN*: int = BLS_PUBLIC_KEY_LEN + INT_LEN + HASH_LEN + SIGNATURE_LEN

    DIFFICULTY_LEN*:     int = INT_LEN + INT_LEN + HASH_LEN
    MINER_LEN*:          int = BLS_PUBLIC_KEY_LEN + BYTE_LEN
    MERIT_HOLDER_RECORD_LEN*: int = BLS_PUBLIC_KEY_LEN + INT_LEN + HASH_LEN
    BLOCK_HEADER_LEN*:   int = INT_LEN + HASH_LEN + BLS_SIGNATURE_LEN + HASH_LEN + INT_LEN + INT_LEN

    MINT_LEN*:        int = INT_LEN + BLS_PUBLIC_KEY_LEN + INT_LEN
    CLAIM_LEN*:       int = PUBLIC_KEY_LEN + INT_LEN + INT_LEN + BLS_SIGNATURE_LEN + SIGNATURE_LEN
    SEND_LEN*:        int = PUBLIC_KEY_LEN + INT_LEN + PUBLIC_KEY_LEN + MEROS_LEN + INT_LEN + SIGNATURE_LEN
    RECEIVE_LEN*:     int = PUBLIC_KEY_LEN + INT_LEN + PUBLIC_KEY_LEN + INT_LEN + SIGNATURE_LEN
    DATA_PREFIX_LEN*: int = PUBLIC_KEY_LEN + INT_LEN + BYTE_LEN
    DATA_SUFFIX_LEN*: int = INT_LEN + SIGNATURE_LEN

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
