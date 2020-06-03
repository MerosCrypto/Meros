import ../../lib/[Errors, Hash]

import ../../Wallet/[Wallet, MinerWallet]

import objects/[MintObj, ClaimObj]
export ClaimObj

import ../../Network/Serialize/Transactions/SerializeClaim

proc newClaim*(
  inputs: varargs[FundedInput],
  output: EdPublicKey
): Claim {.forceCheck: [
  ValueError
].} =
  #Verify the inputs length.
  if inputs.len < 1 or 255 < inputs.len:
    raise newLoggedException(ValueError, "Claim has too little or too many inputs.")

  result = newClaimObj(inputs, output)

proc sign*(
  wallet: MinerWallet,
  claim: Claim
) {.forceCheck: [].} =
  #Create a seq of signatures.
  var signatures: seq[BLSSignature] = newSeq[BLSSignature](claim.inputs.len)

  #Sign every input.
  for i in 0 ..< signatures.len:
    signatures[i] = wallet.sign(
      "\1" &
      claim.inputs[i].hash.toString() &
      char(cast[FundedInput](claim.inputs[i]).nonce) &
      cast[SendOutput](claim.outputs[0]).key.toString()
    )

  #Aggregate the input signatures.
  claim.signature = signatures.aggregate()

  #Hash the Claim.
  claim.hash = Blake256(claim.serializeHash())

#Verify a Claim.
proc verify*(
  claim: Claim,
  claimers: seq[BLSPublicKey]
): bool {.forceCheck: [].} =
  var agInfos: seq[BLSAggregationInfo] = newSeq[BLSAggregationInfo](claim.inputs.len)

  #Create each AggregationInfo.
  for i in 0 ..< claim.inputs.len:
    try:
      agInfos[i] = newBLSAggregationInfo(
        claimers[i],
        (
          "\1" &
          claim.inputs[i].hash.toString() &
          char(cast[FundedInput](claim.inputs[i]).nonce) &
          cast[SendOutput](claim.outputs[0]).key.toString()
        )
      )
    except BLSError as e:
      panic("Infinite BLS Public Key entered the system: " & e.msg)

  try:
    result = claim.signature.verify(agInfos.aggregate())
  except BLSError as e:
    panic("Couldn't verify a signature: " & e.msg)
