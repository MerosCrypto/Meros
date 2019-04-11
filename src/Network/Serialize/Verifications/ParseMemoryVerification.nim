#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Verification object.
import ../../../Database/Verifications/objects/VerificationObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Finals lib.
import finals

#Parse a Memory Verification.
proc parseMemoryVerification*(
    verifStr: string
): MemoryVerification {.forceCheck: [
    ValueError,
    BLSError
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
        verifier: BLSPublicKey
        #Nonce.
        nonce: uint = uint(verifSeq[1].fromBinary())
        #Get the Entry hash.
        entry: string = verifSeq[2]
        #BLS signature.
        sig: BLSSignature

    try:
        verifier = newBLSPublicKey(verifSeq[0])
        sig = newBLSSignature(verifSeq[3])
    except BLSError as e:
        raise e

    #Create the Verification.
    try:
        result = newMemoryVerificationObj(
            entry.toHash(384)
        )
        result.verifier = verifier
        result.nonce = nonce
        result.signature = sig
    except ValueError as e:
        raise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Memory Verification: " & e.msg)
