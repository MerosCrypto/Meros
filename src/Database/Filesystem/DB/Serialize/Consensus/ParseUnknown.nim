#Errors lib.
import ../../../../../lib/Errors

#Hash lib.
import ../../../../../lib/Hash

#MinerWallet lib.
import ../../../../../Wallet/MinerWallet

#Verification object.
import ../../../../Consensus/objects/VerificationObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Parse function.
proc parseUnknown*(
    unknownStr: string
): Verification {.forceCheck: [
    ValueError,
    BLSError
].} =
    #Holder | Hash
    var unknownSeq: seq[string] = unknownStr.deserialize(
        BLS_PUBLIC_KEY_LEN,
        HASH_LEN
    )

    try:
        result = newVerificationObj(
            unknownSeq[1].toHash(384)
        )
    except ValueError as e:
        fcRaise e

    try:
        result.holder = newBLSPublicKey(unknownSeq[0])
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing an Unknown: " & e.msg)
    except BLSError as e:
        fcRaise e
