#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Verification object.
import ../../../Database/Consensus/Elements/objects/VerificationObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Parse a Verification.
proc parseVerification*(
  verifStr: string
): Verification {.forceCheck: [
  ValueError
].} =
  #Holder's Nickname | Transaction Hash
  var verifSeq: seq[string] = verifStr.deserialize(
    NICKNAME_LEN,
    HASH_LEN
  )

  #Create the Verification.
  try:
    result = newVerificationObj(
      verifSeq[1].toHash(256)
    )
    result.holder = uint16(verifSeq[0].fromBinary())
  except ValueError as e:
    raise e

#Parse a Signed Verification.
proc parseSignedVerification*(
  verifStr: string
): SignedVerification {.forceCheck: [
  ValueError
].} =
  #Holder's Nickname | Transaction Hash | BLS Signature
  var verifSeq: seq[string] = verifStr.deserialize(
    NICKNAME_LEN,
    HASH_LEN,
    BLS_SIGNATURE_LEN
  )

  #Create the Verification.
  try:
    result = newSignedVerificationObj(
      verifSeq[1].toHash(256)
    )
    result.holder = uint16(verifSeq[0].fromBinary())
    result.signature = newBLSSignature(verifSeq[2])
  except ValueError as e:
    raise e
  except BLSError:
    raise newLoggedException(ValueError, "Invalid signature.")
