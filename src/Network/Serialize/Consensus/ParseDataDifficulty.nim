#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#DataDifficulty object.
import ../../../Database/Consensus/Elements/objects/DataDifficultyObj

#Serialize/Deserialize functions.
import ../SerializeCommon

#Parse a DataDifficulty.
proc parseDataDifficulty*(
    dataDiffStr: string
): DataDifficulty {.forceCheck: [].} =
    #Holder's Nickname | Nonce | Difficulty
    var dataDiffSeq: seq[string] = dataDiffStr.deserialize(
        NICKNAME_LEN,
        INT_LEN,
        INT_LEN
    )

    #Create the DataDifficulty.
    try:
        result = newDataDifficultyObj(
            dataDiffSeq[1].fromBinary(),
            uint32(dataDiffSeq[2].fromBinary())
        )
        result.holder = uint16(dataDiffSeq[0].fromBinary())
    except ValueError as e:
        panic("Failed to parse a 32-byte hash: " & e.msg)

#Parse a Signed DataDifficulty.
proc parseSignedDataDifficulty*(
    dataDiffStr: string
): SignedDataDifficulty {.forceCheck: [
    ValueError
].} =
    #Holder's Nickname | Nonce | Difficulty | BLS Signature
    var dataDiffSeq: seq[string] = dataDiffStr.deserialize(
        NICKNAME_LEN,
        INT_LEN,
        INT_LEN,
        BLS_SIGNATURE_LEN
    )

    #Create the DataDifficulty.
    try:
        result = newSignedDataDifficultyObj(
            dataDiffSeq[1].fromBinary(),
            uint32(dataDiffSeq[2].fromBinary())
        )
        result.holder = uint16(dataDiffSeq[0].fromBinary())
        result.signature = newBLSSignature(dataDiffSeq[3])
    except ValueError as e:
        panic("Failed to parse a 32-byte hash: " & e.msg)
    except BLSError:
        raise newLoggedException(ValueError, "Invalid signature.")
