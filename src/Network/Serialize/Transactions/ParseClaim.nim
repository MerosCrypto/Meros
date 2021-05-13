import ../../../lib/[Errors, Hash]
import ../../../Wallet/[Wallet, MinerWallet]

import ../../../Database/Transactions/objects/ClaimObj

import ../SerializeCommon

proc parseClaim*(
  claimStr: string
): Claim {.forceCheck: [
  ValueError
].} =
  #Verify the input length.
  if claimStr.len < BYTE_LEN:
    raise newLoggedException(ValueError, "parseClaim not handed enough data to get the amount of inputs.")
  if claimStr.len != (
    BYTE_LEN +
    (int(claimStr[0]) * (HASH_LEN + BYTE_LEN)) +
    RISTRETTO_PUBLIC_KEY_LEN +
    BLS_SIGNATURE_LEN
  ):
    raise newLoggedException(ValueError, "parseClaim handed the wrong amount of data.")

  #Inputs Length | Inputs | Output Ristretto Key | BLS Signature
  var claimSeq: seq[string] = claimStr.deserialize(
    BYTE_LEN,
    int(claimStr[0]) * (HASH_LEN + BYTE_LEN),
    RISTRETTO_PUBLIC_KEY_LEN,
    BLS_SIGNATURE_LEN
  )

  #Convert the inputs.
  var inputs: seq[FundedInput] = newSeq[FundedInput](int(claimSeq[0][0]))
  if inputs.len == 0:
    raise newLoggedException(ValueError, "parseClaim handed a Claim with no inputs.")
  for i in countup(0, claimSeq[1].len - 1, HASH_LEN + BYTE_LEN):
    inputs[i div (HASH_LEN + BYTE_LEN)] = newFundedInput(
      claimSeq[1][i ..< i + HASH_LEN].toHash[:256](),
      int(claimSeq[1][i + HASH_LEN])
    )

  #Create the Claim.
  result = newClaimObj(inputs, newRistrettoPublicKey(claimSeq[2]))
  result.hash = Blake256("\1" & claimStr[0 ..< claimStr.len - BLS_SIGNATURE_LEN])

  #Set the signature.
  try:
    result.signature = newBLSSignature(claimSeq[3])
  except BLSError:
    raise newLoggedException(ValueError, "Invalid Signature.")
