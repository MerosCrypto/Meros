import ../../lib/[Errors, Util, Hash]

import ../../Wallet/Wallet

import objects/SendObj
export SendObj

import ../../Network/Serialize/Transactions/SerializeSend

proc newSend*(
  inputs: varargs[FundedInput],
  outputs: varargs[SendOutput]
): Send {.forceCheck: [].} =
  result = newSendObj(inputs, outputs)
  result.hash = Blake256(result.serializeHash())

proc sign*(
  wallet: HDWallet,
  send: Send
) {.inline, forceCheck: [].} =
  send.signature = wallet.sign(send.hash.serialize())

proc mine*(
  send: Send,
  baseDifficulty: uint32
) {.forceCheck: [].} =
  #Not really needed, and will trigger a re-mine if this is accidentally called twice.
  #Keeps things clean though.
  send.proof = 0
  while send.overflows(baseDifficulty):
    inc(send.proof)
