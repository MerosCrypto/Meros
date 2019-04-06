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

#Parse a Verification.
proc parseMemoryVerification*(
    verifStr: string
): MemoryVerification {.raises: [
    ValueError,
    BLSError,
    FinalAttributeError
].} =
    var
        #BLS Public Key | Nonce | Entry Hash | BLS Signature
        verifSeq: seq[string] = verifStr.deserialize(
            BLS_PUBLIC_KEY_LEN,
            INT_LEN,
            HASH_LEN,
            BLS_SIGNATURE_LEN
        )
        #Verifier's Public Key.
        verifier: BLSPublicKey = newBLSPublicKey(verifSeq[0])
        #Nonce.
        nonce: uint = uint(verifSeq[1].fromBinary())
        #Get the Entry hash.
        entry: string = verifSeq[2]
        #BLS signature.
        sig: BLSSignature = newBLSSignature(verifSeq[3])

    #Create the Verification.
    result = newMemoryVerificationObj(
        entry.toHash(384)
    )
    result.verifier = verifier
    result.nonce = nonce
    result.signature = sig
