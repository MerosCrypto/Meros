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
import BLS

#String utils standard lib.
import strutils

#Parse a Verification.
func parseVerification*(
    verifStr: string
): MemoryVerification {.raises: [
    ValueError,
    FinalAttributeError
].} =
    var
        #Public Key | Node Hash | Signature
        verifSeq: seq[string] = verifStr.deserialize(3)
        #Get the Verifier's Public Key.
        verifier: PublicKey = newPublicKeyFromBytes(verifSeq[0].pad(48, char(0)))
        #Get the Node hash.
        node: string = verifSeq[1].pad(64, char(0))
        #Get the BLS signature.
        sig: Signature = newSignatureFromBytes(verifSeq[2].pad(96, char(0)))

    #Create the Verification.
    result = newMemoryVerificationObj(
        node.toHash(512)
    )
    result.verifier = verifier

    #Verify the BLS signature.
    sig.setAggregationInfo(
        newAggregationInfoFromMsg(verifier, result.hash.toString())
    )
    if not sig.verify():
        raise newException(ValueError, "Received signature was invalid.")
    #Set the signature.
    result.signature = sig
