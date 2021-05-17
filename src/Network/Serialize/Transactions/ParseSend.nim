import ../../../lib/[Errors, Hash]
import ../../../Wallet/Wallet

import ../../../Database/Transactions/objects/SendObj

import ../SerializeCommon

#A theoretical version of the function supporting missing work is available at https://gist.github.com/kayabaNerve/a03fdc506a00069e81c29afc5d6816bb.
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
  if sendStr.len != (
    BYTE_LEN +
    (sendStr[0].fromBinary() * (HASH_LEN + BYTE_LEN)) +
    BYTE_LEN +
    (sendStr[outputLenPos].fromBinary() * (RISTRETTO_PUBLIC_KEY_LEN + MEROS_LEN)) +
    RISTRETTO_SIGNAURE_LEN +
    INT_LEN
  ):
    raise newLoggedException(ValueError, "parseSend handed the wrong amount of data.")

  #Inputs Length | Inputs | Outputs Length | Signature | Proof
  var sendSeq: seq[string] = sendStr.deserialize(
    BYTE_LEN,
    sendStr[0].fromBinary() * (HASH_LEN + BYTE_LEN),
    BYTE_LEN,
    sendStr[outputLenPos].fromBinary() * (RISTRETTO_PUBLIC_KEY_LEN + MEROS_LEN),
    RISTRETTO_SIGNAURE_LEN,
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
      newRistrettoPublicKey(sendSeq[3][i ..< i + 32]),
      uint64(sendSeq[3][i + 32 ..< i + 40].fromBinary())
    )

  #Create the Send.
  result = newSendObj(inputs, outputs)
  result.hash = Blake256("\2" & sendStr[0 ..< sendStr.len - (RISTRETTO_SIGNAURE_LEN + INT_LEN)])
  result.signature = cast[seq[byte]](sendSeq[4])
  result.proof = uint32(sendSeq[5].fromBinary())

  #Verify the Send isn't spam.
  if result.overflows(diff):
    raise newSpam("Send didn't beat the difficulty.", result.hash, result.getDifficultyFactor() * diff)
