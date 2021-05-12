import ../../lib/[Errors, Hash]

import ../../Wallet/[Wallet, MinerWallet]

import objects/[MintObj, ClaimObj]
export ClaimObj

import ../../Network/Serialize/Transactions/SerializeClaim

proc newClaim*(
  inputs: varargs[FundedInput],
  output: RistrettoPublicKey
): Claim {.forceCheck: [
  ValueError
].} =
  #Verify the inputs length.
  if inputs.len < 1 or 255 < inputs.len:
    raise newLoggedException(ValueError, "Claim has too little or too many inputs.")
  result = newClaimObj(inputs, output)
  result.hash = Blake256(result.serializeHash())

proc sign*(
  wallet: MinerWallet,
  claim: Claim
) {.forceCheck: [].} =
  claim.signature = wallet.sign(claim.hash.serialize())

#Verify a Claim.
proc verify*(
  claim: Claim,
  claimer: BLSPublicKey
): bool {.forceCheck: [].} =
  try:
    result = claim.signature.verify(newBLSAggregationInfo(claimer, claim.hash.serialize()))
  except BLSError as e:
    panic("Couldn't verify a signature: " & e.msg)
