#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Verification object.
import ../../../Database/Consensus/objects/VerificationObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Parse a Verification.
proc parseVerification*(
    verifStr: string
): Verification {.forceCheck: [
    ValueError,
    BLSError
].} =
    #BLS Public Key | Nonce | Transaction Hash
    var verifSeq: seq[string] = verifStr.deserialize(
        BLS_PUBLIC_KEY_LEN,
        INT_LEN,
        HASH_LEN
    )

    #Create the Verification.
    try:
        result = newVerificationObj(
            verifSeq[2].toHash(384)
        )
        result.holder = newBLSPublicKey(verifSeq[0])
        result.nonce = verifSeq[1].fromBinary()
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Verification: " & e.msg)

#Parse a Signed Verification.
proc parseSignedVerification*(
    verifStr: string
): SignedVerification {.forceCheck: [
    ValueError,
    BLSError
].} =
    #BLS Public Key | Nonce | Transaction Hash | BLS Signature
    var verifSeq: seq[string] = verifStr.deserialize(
        BLS_PUBLIC_KEY_LEN,
        INT_LEN,
        HASH_LEN,
        BLS_SIGNATURE_LEN
    )

    #Create the Verification.
    try:
        result = newSignedVerificationObj(
            verifSeq[2].toHash(384)
        )
        result.holder = newBLSPublicKey(verifSeq[0])
        result.nonce = verifSeq[1].fromBinary()
        result.signature = newBLSSignature(verifSeq[3])
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Signed Verification: " & e.msg)
