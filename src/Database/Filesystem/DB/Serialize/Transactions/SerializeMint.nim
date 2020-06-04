import ../../../../../lib/[Errors, Util]

import ../../../../Transactions/objects/MintObj

import ../../../../../Network/Serialize/SerializeCommon
import SerializeMintOutput

proc serialize*(
  mint: Mint
): string {.inline, forceCheck: [].} =
  result = mint.outputs.len.toBinary(INT_LEN)
  for output in mint.outputs:
    result &= cast[MintOutput](output).serialize()
