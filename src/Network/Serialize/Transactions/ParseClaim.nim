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

  #Inputs Length | Inputs | Output Ed25519 Key | BLS Signatture
  var claimSeq: seq[string] = claimStr.deserialize(
    BYTE_LEN,
    int(claimStr[0]) * (HASH_LEN + BYTE_LEN),
    ED_PUBLIC_KEY_LEN,
    BLS_SIGNATURE_LEN
  )

  #Convert the inputs.
  var inputs: seq[FundedInput] = newSeq[FundedInput](int(claimSeq[0][0]))
  if inputs.len == 0:
    raise newLoggedException(ValueError, "parseClaim handed a Claim with no inputs.")
  for i in countup(0, claimSeq[1].len - 1, HASH_LEN + BYTE_LEN):
    try:
      inputs[i div (HASH_LEN + BYTE_LEN)] = newFundedInput(
        claimSeq[1][i ..< i + HASH_LEN].toHash[:256](),
        int(claimSeq[1][i + HASH_LEN])
      )
    except ValueError as e:
      raise e

  #Create the Claim.
  try:
    result = newClaimObj(
      inputs,
      newEdPublicKey(claimSeq[2])
    )
  except ValueError as e:
    raise e

  #Set the signature and hash it.
  try:
    result.signature = newBLSSignature(claimSeq[3])
    result.hash = Blake256("\1" & claimSeq[3])
  except BLSError:
    raise newLoggedException(ValueError, "Invalid Signature.")
