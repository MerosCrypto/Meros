import ../../../../../lib/[Errors, Util]

import ../../../../Transactions/objects/TransactionObj

import ../../../../../Network/Serialize/SerializeCommon

import SerializeOutput
export SerializeOutput

method serialize*(
  output: MintOutput
): string {.inline, forceCheck: [].} =
  output.key.toBinary(NICKNAME_LEN) &
  output.amount.toBinary(MEROS_LEN)
