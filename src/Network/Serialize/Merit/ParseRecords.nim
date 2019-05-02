#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#VerifierRecord object.
import ../../../Database/common/objects/VerifierRecordObj

#Common serialization functions.
import ../SerializeCommon

#Parse Records.
proc parseRecords*(
    recordsStr: string
): seq[VerifierRecord] {.forceCheck: [
    ValueError,
    BLSError
], fcBoundsOverride.} =
    #Quantity | BLS Key 1 | Nonce 1 | Merkle 1 .. BLS Key N | Nonce N | Merkle N
    var
        quantity: int = recordsStr.substr(0, INT_LEN - 1).fromBinary()
        recordSeq: seq[string]

    #Init the result.
    result = newSeq[VerifierRecord](quantity)

    #Parse each VerifierRecord.
    for i in 0 ..< quantity:
        recordSeq = recordsStr
            .substr(INT_LEN + (i * VERIFIER_INDEX_LEN))
            .deserialize(
                BLS_PUBLIC_KEY_LEN,
                INT_LEN,
                HASH_LEN
            )

        try:
            result[i] = newVerifierRecord(
                newBLSPublicKey(recordSeq[0]),
                recordSeq[1].fromBinary(),
                recordSeq[2].toHash(384)
            )
        except ValueError as e:
            fcRaise e
        except BLSError as e:
            fcRaise e
