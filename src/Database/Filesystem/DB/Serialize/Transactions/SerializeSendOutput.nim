import ../../../../../lib/[Errors, Util]
import ../../../../../Wallet/Wallet

import ../../../../Transactions/objects/TransactionObj

import ../../../../../Network/Serialize/SerializeCommon

import SerializeOutput
export SerializeOutput

method serialize*(
  output: SendOutput
): string {.inline, forceCheck: [].} =
  output.key.toString() &
  output.amount.toBinary(MEROS_LEN)
