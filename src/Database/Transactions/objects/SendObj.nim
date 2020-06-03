import ../../../lib/[Errors, Hash]
import ../../../Wallet/Wallet

import TransactionObj
export TransactionObj

type Send* = ref object of Transaction
  signature*: EdSignature
  proof*: uint32
  argon*: Hash[256]

func newSendObj*(
  inputs: varargs[FundedInput],
  outputs: varargs[SendOutput]
): Send {.inline, forceCheck: [].} =
  Send(
    inputs: cast[seq[Input]](@inputs),
    outputs: cast[seq[Output]](@outputs)
  )

#Get the difficulty factor of a specific Send.
proc getDifficultyFactor*(
  send: Send
): uint32 {.inline, forceCheck: [].} =
  (
    uint32(70) +
    (uint32(33) * uint32(send.inputs.len)) +
    (uint32(40) * uint32(send.outputs.len))
  ) div uint32(143)
