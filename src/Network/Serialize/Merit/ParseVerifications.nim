#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Verification object.
import ../../../Database/Merit/objects/VerificationsObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Parse a Verification.
proc parseVerification*(
    verifStr: string
): MemoryVerification {.raises: [
    ValueError,
    BLSError,
    FinalAttributeError
].} =
    var
        #Public Key | Entry Hash | Signature
        verifSeq: seq[string] = verifStr.deserialize(3)
        #Verifier's Public Key.
        verifier: BLSPublicKey = newBLSPublicKey(verifSeq[0].pad(48))
        #Get the Entry hash.
        entry: string = verifSeq[1].pad(64)
        #BLS signature.
        sig: BLSSignature = newBLSSignature(verifSeq[2].pad(96))

    #Create the Verification.
    result = newMemoryVerificationObj(
        entry.toHash(512)
    )
    result.verifier = verifier

    #Set the signature.
    result.signature = sig

#Parse Verifications.
proc parseVerifications*(
    verifsStr: string,
    signature: BLSSignature
): Verifications {.raises: [
    ValueError,
    BLSError,
    FinalAttributeError
].} =
    #Create the result.
    result = newVerificationsObj()

    #Deserialize the data.
    var verifsSeq: seq[string] = verifsStr.deserialize()

    for i in countup(0, verifsSeq.len - 1, 2):
        result.verifications.add(
            newMemoryVerificationObj(
                verifsSeq[i].pad(64).toHash(512)
            )
        )
        result.verifications[^1].verifier = newBLSPublicKey(verifsSeq[i+1].pad(48))
