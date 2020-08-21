import ../../lib/[Errors, Util]
export Util

const
  #Lengths of various data types and messages.
  BYTE_LEN*:        int = 1
  PORT_LEN*:        int = 2
  NICKNAME_LEN*:    int = 2
  IP_LEN*:          int = 4
  INT_LEN*:         int = 4
  PEER_LEN*:        int = IP_LEN + PORT_LEN
  SALT_LEN*:        int = 8
  SKETCH_HASH_LEN*: int = 8
  MEROS_LEN*:       int = 8
  HASH_LEN*:        int = 32

  ED_PUBLIC_KEY_LEN*:  int = 32
  ED_SIGNATURE_LEN*:   int = 64
  BLS_PUBLIC_KEY_LEN*: int = 96
  BLS_SIGNATURE_LEN*:  int = 48

  BLOCK_HEADER_DATA_LEN*: int = INT_LEN + HASH_LEN + HASH_LEN + NICKNAME_LEN + INT_LEN + HASH_LEN + BYTE_LEN

  VERIFICATION_PREFIX*:        int = 0
  VERIFICATION_PACKET_PREFIX*: int = 1
  SEND_DIFFICULTY_PREFIX*:     int = 2
  DATA_DIFFICULTY_PREFIX*:     int = 3
  MERIT_REMOVAL_PREFIX*:       int = 5

  #Elements that can be in a MeritRemoval.
  MERIT_REMOVAL_ELEMENT_SET*: set[byte] = {
    byte(VERIFICATION_PREFIX),
    byte(VERIFICATION_PACKET_PREFIX),
    byte(SEND_DIFFICULTY_PREFIX),
    byte(DATA_DIFFICULTY_PREFIX)
  }

  #Elements that can be in a Block.
  BLOCK_ELEMENT_SET*: set[byte] = {
    byte(SEND_DIFFICULTY_PREFIX),
    byte(DATA_DIFFICULTY_PREFIX),
    byte(MERIT_REMOVAL_PREFIX)
  }

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
