#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#Mint object.
import ../../../../Transactions/objects/MintObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Serialize Mint lib.
import SerializeMintOutput

#Serialization function.
proc serialize*(
  mint: Mint
): string {.inline, forceCheck: [].} =
  result = mint.outputs.len.toBinary(INT_LEN)
  for output in mint.outputs:
    result &= cast[MintOutput](output).serialize()
