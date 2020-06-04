import ../../../../../lib/[Errors, Hash]

import ../../../../Transactions/Transaction

import SerializeMint
import ../../../../../Network/Serialize/Transactions/[
  SerializeClaim,
  SerializeSend,
  SerializeData
]

#Helper function to convert an input to a string.
func serialize*(
  input: Input
): string {.forceCheck: [].} =
  result = input.hash.serialize()
  if input of FundedInput:
    result &= char(cast[FundedInput](input).nonce)
  else:
    result &= char(0)

proc serialize*(
  tx: Transaction
): string {.forceCheck: [].} =
  case tx:
    of Mint as mint:
      result = '\0' & mint.serialize()
    of Claim as claim:
      result = '\1' & claim.serialize()
    of Send as send:
      result = '\2' & send.serialize()
    of Data as data:
      result = '\3' & data.serialize()
