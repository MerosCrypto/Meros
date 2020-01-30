#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#SendDifficulty object.
import ../../../Database/Consensus/Elements/objects/SendDifficultyObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Parse a SendDifficulty.
proc parseSendDifficulty*(
    sendDiffStr: string
): SendDifficulty {.forceCheck: [].} =
    #Holder's Nickname | Nonce | Difficulty
    var sendDiffSeq: seq[string] = sendDiffStr.deserialize(
        NICKNAME_LEN,
        INT_LEN,
        HASH_LEN
    )

    #Create the SendDifficulty.
    try:
        result = newSendDifficultyObj(
            sendDiffSeq[1].fromBinary(),
            sendDiffSeq[2].toHash(256)
        )
        result.holder = uint16(sendDiffSeq[0].fromBinary())
    except ValueError as e:
        panic("Failed to parse a 32-byte hash: " & e.msg)

#Parse a Signed SendDifficulty.
proc parseSignedSendDifficulty*(
    sendDiffStr: string
): SignedSendDifficulty {.forceCheck: [
    ValueError
].} =
    #Holder's Nickname | Nonce | Difficulty | BLS Signature
    var sendDiffSeq: seq[string] = sendDiffStr.deserialize(
        NICKNAME_LEN,
        INT_LEN,
        HASH_LEN,
        BLS_SIGNATURE_LEN
    )

    #Create the SendDifficulty.
    try:
        result = newSignedSendDifficultyObj(
            sendDiffSeq[1].fromBinary(),
            sendDiffSeq[2].toHash(256)
        )
        result.holder = uint16(sendDiffSeq[0].fromBinary())
        result.signature = newBLSSignature(sendDiffSeq[3])
    except ValueError as e:
        panic("Failed to parse a 32-byte hash: " & e.msg)
    except BLSError:
        raise newLoggedException(ValueError, "Invalid signature.")
