#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#MeritHolderRecord object.
import ../../../Database/common/objects/MeritHolderRecordObj

#Common serialization functions.
import ../SerializeCommon

#Parse Records.
proc parseRecords*(
    recordsStr: string
): seq[MeritHolderRecord] {.forceCheck: [
    ValueError,
    BLSError
].} =
    #Quantity | BLS Key 1 | Nonce 1 | Merkle 1 .. BLS Key N | Nonce N | Merkle N
    var
        quantity: int = recordsStr.substr(0, INT_LEN - 1).fromBinary()
        recordSeq: seq[string]

    #Init the result.
    result = newSeq[MeritHolderRecord](quantity)

    #Parse each MeritHolderRecord.
    for i in 0 ..< quantity:
        recordSeq = recordsStr
            .substr(INT_LEN + (i * MERIT_HOLDER_RECORD_LEN))
            .deserialize(
                BLS_PUBLIC_KEY_LEN,
                INT_LEN,
                HASH_LEN
            )

        try:
            result[i] = newMeritHolderRecord(
                newBLSPublicKey(recordSeq[0]),
                recordSeq[1].fromBinary(),
                recordSeq[2].toHash(384)
            )
        except ValueError as e:
            fcRaise e
        except BLSError as e:
            fcRaise e
