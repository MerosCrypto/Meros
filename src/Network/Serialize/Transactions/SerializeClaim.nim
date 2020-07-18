import ../../../lib/[Errors, Hash]

import ../../../Wallet/[Wallet, MinerWallet]
import ../../../Wallet/MinerWallet

import ../../../Database/Transactions/objects/ClaimObj

import SerializeTransaction
export SerializeTransaction

method serializeHash*(
  claim: Claim
): string {.forceCheck: [].} =
  result = "\1" & $char(claim.inputs.len)
  for input in claim.inputs:
    result &= input.hash.serialize() & char(cast[FundedInput](input).nonce)
  result &= cast[SendOutput](claim.outputs[0]).key.serialize()

method serialize*(
  claim: Claim
): string {.inline, forceCheck: [].} =
  #Serialize the inputs.
  result = $char(claim.inputs.len)
  for input in claim.inputs:
    result &= input.hash.serialize() & char(cast[FundedInput](input).nonce)

  #Serialize the output and signature.
  result &=
    cast[SendOutput](claim.outputs[0]).key.serialize() &
    claim.signature.serialize()
