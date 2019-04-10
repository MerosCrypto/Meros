#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#VerifierIndex object.
import ../../../Database/common/objects/VerifierIndexObj

#Common serialization functions.
import ../SerializeCommon

#Finals lib.
import finals

#Parse Indexes.
proc parseIndexes*(
    indexesStr: string
): seq[VerifierIndex] {.raises: [ValueError].} =
    #Quantity | BLS Key 1 | Nonce 1 | Merkle 1 .. BLS Key N | Nonce N | Merkle N
    var
        quantity: int = indexesStr[0 ..< INT_LEN].fromBinary()
        indexSeq: seq[string]

    #Init the result.
    result = newSeq[VerifierIndex](quantity)

    #Parse each VerifierIndex.
    for i in 0 ..< quantity:
        indexSeq = indexesStr
            .substr(INT_LEN + (i * VERIFIER_INDEX_LEN))
            .deserialize(
                BLS_PUBLIC_KEY_LEN,
                INT_LEN,
                HASH_LEN
            )

        result[i] = newVerifierIndex(
            indexSeq[0],
            indexSeq[1].fromBinary(),
            indexSeq[2].toHash(384)
        )
