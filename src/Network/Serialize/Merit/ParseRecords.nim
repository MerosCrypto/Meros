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

#Finals lib.
import finals

#Parse Records.
proc parseRecords*(
    recordsStr: string
): seq[VerifierRecord] {.forceCheck: [
    ValueError,
    BLSError
].} =
    #Quantity | BLS Key 1 | Nonce 1 | Merkle 1 .. BLS Key N | Nonce N | Merkle N
    var
        quantity: int = recordsStr[0 ..< INT_LEN].fromBinary()
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
            raise e
        except BLSError as e:
            raise e
