import ../../../lib/[Errors, Hash]
import ../../../Wallet/Wallet

import ../../../Database/Transactions/objects/SendObj

import ../SerializeCommon

proc parseSend*(
  sendStr: string,
  diff: uint32
): Send {.forceCheck: [
  ValueError,
  Spam
].} =
  #Verify the input length.
  if sendStr.len < BYTE_LEN:
    raise newLoggedException(ValueError, "parseSend not handed enough data to get the amount of inputs.")
  let outputLenPos: int = BYTE_LEN + (int(sendStr[0]) * (HASH_LEN + BYTE_LEN))
  if sendStr.len < outputLenPos + BYTE_LEN:
    raise newLoggedException(ValueError, "parseSend not handed enough data to get the amount of outputs.")

  #Inputs Length | Inputs | Outputs Length | Signature | Proof
  var sendSeq: seq[string] = sendStr.deserialize(
    BYTE_LEN,
    sendStr[0].fromBinary() * (HASH_LEN + BYTE_LEN),
    BYTE_LEN,
    sendStr[outputLenPos].fromBinary() * (ED_PUBLIC_KEY_LEN + MEROS_LEN),
    ED_SIGNATURE_LEN,
    INT_LEN
  )

  #Convert the inputs.
  var inputs: seq[FundedInput] = newSeq[FundedInput](sendSeq[0].fromBinary())
  if inputs.len == 0:
    raise newLoggedException(ValueError, "parseSend handed a Send with no inputs.")
  for i in countup(0, sendSeq[1].len - 1, 33):
    inputs[i div 33] = newFundedInput(sendSeq[1][i ..< i + 32].toHash[:256](), sendSeq[1][i + 32].fromBinary())

  #Convert the outputs.
  var outputs: seq[SendOutput] = newSeq[SendOutput](sendSeq[2].fromBinary())
  if outputs.len == 0:
    raise newLoggedException(ValueError, "parseSend handed a Send with no outputs.")
  for i in countup(0, sendSeq[3].len - 1, 40):
    outputs[i div 40] = newSendOutput(
      newEdPublicKey(sendSeq[3][i ..< i + 32]),
      uint64(sendSeq[3][i + 32 ..< i + 40].fromBinary())
    )

  #Create the Send.
  result = newSendObj(inputs, outputs)

  #Verify the Send isn't spam.
  var
    hash: Hash[256] = Blake256("\2" & sendStr[0 ..< sendStr.len - (ED_SIGNATURE_LEN + INT_LEN)])
    argon: Hash[256] = Argon(hash.serialize(), sendSeq[5].pad(8))
    factor: uint32 = result.getDifficultyFactor()
  if argon.overflows(factor * diff):
    raise newSpam("Send didn't beat the difficulty.", hash, argon, factor * diff)

  result.hash = hash
  result.signature = newEdSignature(sendSeq[4])
  result.proof = uint32(sendSeq[5].fromBinary())
  result.argon = argon
