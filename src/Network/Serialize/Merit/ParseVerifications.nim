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
    #Init the result.
    result = @[]

    #Key1 | Nonce 1 | Merkle1 .. KeyN | NonceN | MerkleN
    var verifsSeq: seq[string] = verifsStr.deserialize(3)

    #Parse each VerifierIndex.
    var verifier: VerifierIndex
    for i in countup(0, verifsSeq.len - 1, 3):
        #Create the VerifierIndex.
        verifier = newVerifierIndex(
            verifsSeq[i].pad(48),
            uint(verifsSeq[i + 1].fromBinary()),
            verifsSeq[i + 2].pad(64)
        )

        #Push the VerifierIndex to the seq.
        result.add(verifier)
