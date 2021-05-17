import ../../../lib/[Errors, Util, Hash]

import TransactionObj
export TransactionObj

type Send* = ref object of Transaction
  #This used to be an array and would always have 64 bytes.
  #With the move to a seq[byte] from Ristretto, this premise changes, and this actually caused a test to fail as it didn't set a signature.
  #We could have the below constructor set a length of 64 to regain this behavior, yet then we couldn't detect if it was already signed.
  #That said, we already don't do that as we have a quality signature flow which didn't need to.
  #No other tests/code made any assumption, leaving their behavior unchanged.
  #Because of all of this, this behavior change has solely been documented for now.
  signature*: seq[byte]
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

#Check if the Send's argon hash overflows against the specified difficulty.
proc overflows*(
  send: Send,
  baseDifficulty: uint32
): bool {.forceCheck: [].} =
  if baseDifficulty == 0:
    return false

  result = Argon(
    send.hash.serialize(),
    send.proof.toBinary(8)
  ).overflows(send.getDifficultyFactor() * baseDifficulty)
