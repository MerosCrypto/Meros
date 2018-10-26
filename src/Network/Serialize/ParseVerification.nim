#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Verification object.
import ../../Database/Merit/objects/VerificationsObj

#Serialize/Deserialize functions.
import SerializeCommon
import SerializeVerification

#Finals lib.
import finals

#BLS lib.
import ../../lib/BLS

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

    #Verify the BLS signature.
    sig.setAggregationInfo(
        newBLSAggregationInfo(verifier, result.hash.toString())
    )
    if not sig.verify():
        raise newException(ValueError, "Received signature was invalid.")

    #Set the signature.
    result.signature = sig
