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

#Parse a Memory Verification.
proc parseMemoryVerification*(
    verifStr: string
): MemoryVerification {.forceCheck: [
    ValueError,
    BLSError
].} =
    #BLS Public Key | Nonce | Entry Hash | BLS Signature
    var verifSeq: seq[string] = verifStr.deserialize(
        BLS_PUBLIC_KEY_LEN,
        INT_LEN,
        HASH_LEN,
        BLS_SIGNATURE_LEN
    )

    #Create the Verification.
    try:
        result = newMemoryVerificationObj(
            verifSeq[2].toHash(384)
        )
        result.verifier = newBLSPublicKey(verifSeq[0])
        result.nonce = verifSeq[1].fromBinary()
        result.signature = newBLSSignature(verifSeq[3])
    except BLSError as e:
        fcRaise e
    except ValueError as e:
        fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Memory Verification: " & e.msg)
