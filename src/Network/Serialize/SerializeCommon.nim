import ../../lib/[Errors, Util]
export Util

const
  #Lengths of various data types and messages.
  BYTE_LEN*:        int = 1
  PORT_LEN*:        int = 2
  NICKNAME_LEN*:    int = 2
  DIFFICULTY_LEN*:  int = 2 #Refers to Send/Data, not Block.
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

  BLOCK_HEADER_DATA_LEN*: int = INT_LEN + HASH_LEN + HASH_LEN + INT_LEN + INT_LEN + HASH_LEN + BYTE_LEN

  #These prefixes are used when creating signatures.
  #With the exception of Verification's, they're also used in the BlockHeader's contents Merkle.
  VERIFICATION_PREFIX*:        int = 0
  VERIFICATION_PACKET_PREFIX*: int = 1
  SEND_DIFFICULTY_PREFIX*:     int = 2
  DATA_DIFFICULTY_PREFIX*:     int = 3

  #[
  Merit Removals aren't signed.
  Ever since implicit Merit Removals, they're no longer part of the contents Merkle.
  That said, getLength still uses this for context when handling SignedMeritRemovals.
  ]#
  MERIT_REMOVAL_PREFIX*:       int = 255

  #Elements that can be in a MeritRemoval.
  MERIT_REMOVAL_ELEMENT_SET*: set[byte] = {
    byte(VERIFICATION_PREFIX),
    byte(SEND_DIFFICULTY_PREFIX),
    byte(DATA_DIFFICULTY_PREFIX)
  }

  #Elements that can be in a Block.
  BLOCK_ELEMENT_SET*: set[byte] = {
    byte(SEND_DIFFICULTY_PREFIX),
    byte(DATA_DIFFICULTY_PREFIX)
  }

type Handshake* = object
  protocol*: uint
  network*: uint
  services*: uint
  port*: int
  hash*: string

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

func parseVarInt(
  msg: string,
  cursor: var int
): uint {.forceCheck: [].} =
  var
    last: byte = 0b1 shl 7
    count: int = 0
  while (last shr 7) == 1:
    last = byte(msg[cursor])
    result += uint(last and byte(0b1111111)) shl (count * 7)
    inc(cursor)
    inc(count)

#Handshake parser. It doesn't fit into Transactions/Consensus/Merit.
func parseHandshake*(
  msg: string
): Handshake {.forceCheck: [].} =
  var cursor: int = 0
  result.protocol = msg.parseVarInt(cursor)
  result.network = msg.parseVarInt(cursor)
  result.services = msg.parseVarInt(cursor)
  result.port = msg[cursor .. cursor + 1].fromBinary()
  result.hash = msg[cursor + 2 ..< msg.len]
