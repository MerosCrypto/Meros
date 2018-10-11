#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Wallet lib.
import ../../Wallet/Wallet

#Verification object.
import ../../Database/Merit/objects/VerificationsObj

#Serialize/Deserialize functions.
import SerializeCommon
import SerializeVerification

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Parse a Verification.
proc parseVerification*(
    verifStr: string
): MemoryVerification {.raises: [
    ValueError,
    SodiumError,
    FinalAttributeError
].} =
    var
        #Public Key | Node Hash | ED25519 Signature
        verifSeq: seq[string] = verifStr.deserialize(3)
        #Get the Verifier's Public Key.
        verifier: PublicKey = newPublicKey(verifSeq[0].pad(32, char(0)))
        #Get the Node hash.
        node: string = verifSeq[1].pad(64, char(0))
        #Get the Ed25519 signature.
        edSignature: string = verifSeq[2].pad(64, char(0))

    #Create the Verification.
    result = newMemoryVerificationObj(
        node.toHash(512)
    )
    result.sender = newAddress(verifier)

    #Verify the Ed25519 signature.
    if not verifier.verify(result.hash.toString(), edSignature):
        raise newException(ValueError, "Received signature was invalid.")
    #Set the Ed25519 signature.
    result.edSignature = edSignature
