discard """
    Please read the note in SerializeVerifications before handling this file.
"""

#Util lib.
import ../../../lib/Util

#VerifierIndex object.
import ../../../Database/Merit/objects/VerifierIndexObj

#Common serialization functions.
import ../SerializeCommon

#Finals lib.
import finals

#Parse function.
proc parseVerifications*(
    verifsStr: string
): seq[VerifierIndex] {.raises: [
    FinalAttributeError
].} =
    #Quantity | Key 1 | Nonce 1 | Merkle 1 .. Key N | Nonce N | Merkle N
    var
        quantity: int = verifsStr[0 ..< INT_LEN].fromBinary()
        verifsSeq: seq[string]

    #Init the result.
    result = newSeq[VerifierIndex](quantity)

    #Parse each VerifierIndex.
    for i in 0 ..< quantity:
        verifsSeq = verifsStr
            .substr(INT_LEN + (i * VERIFIER_INDEX_LEN))
            .deserialize(
                BLS_PUBLIC_KEY_LEN,
                INT_LEN,
                HASH_LEN
            )

        result[i] = newVerifierIndex(
            verifsSeq[0],
            uint(verifsSeq[1].fromBinary()),
            verifsSeq[2]
        )
