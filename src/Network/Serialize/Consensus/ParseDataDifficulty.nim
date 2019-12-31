#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

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
        HASH_LEN
    )

    #Create the DataDifficulty.
    try:
        result = newDataDifficultyObj(
            dataDiffSeq[1].fromBinary(),
            dataDiffSeq[2].toHash(384)
        )
        result.holder = uint16(dataDiffSeq[0].fromBinary())
    except ValueError as e:
        doAssert(false, "Failed to parse a 48-byte hash: " & e.msg)
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a DataDifficulty: " & e.msg)

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
        HASH_LEN,
        BLS_SIGNATURE_LEN
    )

    #Create the DataDifficulty.
    try:
        result = newSignedDataDifficultyObj(
            dataDiffSeq[1].fromBinary(),
            dataDiffSeq[2].toHash(384)
        )
        result.holder = uint16(dataDiffSeq[0].fromBinary())
        result.signature = newBLSSignature(dataDiffSeq[3])
    except ValueError as e:
        doAssert(false, "Failed to parse a 48-byte hash: " & e.msg)
    except BLSError:
        raise newException(ValueError, "Invalid signature.")
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Signed DataDifficulty: " & e.msg)
