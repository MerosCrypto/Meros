#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Wallet lib.
import ../../Wallet/Wallet

#Send object.
import objects/SendObj
export SendObj

#Serialization libs.
import ../../Network/Serialize/SerializeCommon
import ../../Network/Serialize/Transactions/SerializeSend

#Create a new Send.
proc newSend*(
  inputs: varargs[FundedInput],
  outputs: varargs[SendOutput]
): Send {.forceCheck: [].} =
  #Create the Send.
  result = newSendObj(
    inputs,
    outputs
  )

  #Hash it.
  result.hash = Blake256(result.serializeHash())

#Sign a Send.
proc sign*(
  wallet: HDWallet,
  send: Send
) {.inline, forceCheck: [].} =
  send.signature = wallet.sign(send.hash.toString())

#Mine the Send.
proc mine*(
  send: Send,
  baseDifficulty: uint32
) {.forceCheck: [].} =
  #Generate proofs until the reduced Argon2 hash beats the difficulty.
  var
    difficulty: uint32 = send.getDifficultyFactor() * baseDifficulty
    proof: uint32 = 0
    hash: ArgonHash = Argon(send.hash.toString(), proof.toBinary(SALT_LEN))
  while hash.overflows(difficulty):
    inc(proof)
    hash = Argon(send.hash.toString(), proof.toBinary(SALT_LEN))

  send.proof = proof
  send.argon = hash
