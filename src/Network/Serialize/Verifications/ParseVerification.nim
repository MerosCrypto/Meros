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

#Parse a Verification.
proc parseVerification*(
    verifStr: string
): Verification {.forceCheck: [
    ValueError,
    BLSError
].} =
    var
        #BLS Public Key | Nonce | Entry Hash
        verifSeq: seq[string] = verifStr.deserialize(
            BLS_PUBLIC_KEY_LEN,
            INT_LEN,
            HASH_LEN
        )
        #Verifier's Public Key.
        verifier: BLSPublicKey
        #Nonce.
        nonce: int = verifSeq[1].fromBinary()
        #Get the Entry hash.
        entry: string = verifSeq[2]

    try:
        verifier = newBLSPublicKey(verifSeq[0])
    except BLSError as e:
        raise e

    #Create the Verification.
    try:
        result = newMemoryVerificationObj(
            entry.toHash(384)
        )
        result.verifier = verifier
        result.nonce = nonce
    except ValueError as e:
        raise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Verification: " & e.msg)
