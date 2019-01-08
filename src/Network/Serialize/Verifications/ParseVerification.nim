#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Verification object.
import ../../../Database/Verifications/objects/VerificationObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Finals lib.
import finals

#String utils standard lib.
import strutils

#Parse a Verification.
proc parseVerification*(
    verifStr: string
): Verification {.raises: [
    ValueError,
    BLSError,
    FinalAttributeError
].} =
    var
        #Public Key | Nonce | Entry Hash
        verifSeq: seq[string] = verifStr.deserialize(4)
        #Verifier's Public Key.
        verifier: BLSPublicKey = newBLSPublicKey(verifSeq[0].pad(48))
        #Nonce.
        nonce: uint = uint(verifSeq[1].fromBinary())
        #Get the Entry hash.
        entry: string = verifSeq[1].pad(64)

    #Create the Verification.
    result = newMemoryVerificationObj(
        entry.toHash(512)
    )
    result.verifier = verifier
    result.nonce = nonce
