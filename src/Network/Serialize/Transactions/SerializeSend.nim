import ../../../lib/[Errors, Hash]
import ../../../Wallet/Wallet

import ../../../Database/Transactions/objects/SendObj

import ../SerializeCommon

import SerializeTransaction
export SerializeTransaction

method serializeHash*(
  send: Send
): string {.forceCheck: [].} =
  result = "\2" & char(send.inputs.len)
  for input in send.inputs:
    result &=
      input.hash.serialize() &
      cast[FundedInput](input).nonce.toBinary(BYTE_LEN)
  result &= char(send.outputs.len)
  for output in send.outputs:
    result &=
      cast[SendOutput](output).key.serialize() &
      output.amount.toBinary(MEROS_LEN)

method serialize*(
  send: Send
): string {.inline, forceCheck: [].} =
  #Serialize the inputs.
  result = $char(send.inputs.len)
  for input in send.inputs:
    result &=
      input.hash.serialize() &
      char(cast[FundedInput](input).nonce)

  #Serialize the outputs.
  result &= char(send.outputs.len)
  for output in send.outputs:
    result &=
      cast[SendOutput](output).key.serialize() &
      output.amount.toBinary(MEROS_LEN)

  result &=
    cast[string](send.signature) &
    send.proof.toBinary(INT_LEN)
