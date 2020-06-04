import ../../lib/[Errors, Util, Hash]

import ../../Wallet/Wallet

import objects/SendObj
export SendObj

import ../../Network/Serialize/SerializeCommon
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
  var
    difficulty: uint32 = send.getDifficultyFactor() * baseDifficulty
    proof: uint32 = 0
    hash: Hash[256] = Argon(send.hash.serialize(), proof.toBinary(SALT_LEN))
  while hash.overflows(difficulty):
    inc(proof)
    hash = Argon(send.hash.serialize(), proof.toBinary(SALT_LEN))

  send.proof = proof
  send.argon = hash
