discard """
    Please read the note in SerializeVerifications before handling this file.
"""

#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Merkle lib.
import ../../../lib/Merkle

#Index object.
import ../../../Database/common/objects/IndexObj

#Verifications lib.
import ../../../Database/Verifications/Verifications

#Common serialization functions.
import ../SerializeCommon

#String utils standard library.
import strutils

#Parse function.
proc parseVerifications*(
    indexesStr: string,
    verifs: Verifications
): seq[Index] {.raises: [BLSError].} =
    #Init the result.
    result = @[]

    #Key1 | Nonce 1 | Merkle1 .. KeyN | NonceN | MerkleN
    var indexesSeq: seq[string] = indexesStr.deserialize(3)

    #Create and verify each index.
    var
        #Temporary Index object.
        index: Index
        #Seq of a Verifier's hashes, used to verify the Merkle's.
        hashes: seq[string]
    for i in countup(0, indexesSeq.len - 1, 3):
        #Create the Index.
        index = newIndex(
            indexesSeq[i].pad(48),
            uint(indexesSeq[i + 1].fromBinary())
        )

        #Clear hashes.
        hashes = newSeq[string](index.nonce)
        #Grab every Verificaion until this nonce, for this Verifier.
        for verif in verifs[index.key][0 .. index.nonce]:
            #Add its hash to the seq.
            hashes.add(verif.hash.toString())
        #Test the Merkle against what's in the serialized string.
        if newMerkle(hashes).hash != indexesSeq[i + 2].pad(64):
            raise newException(ValueError, "Our Verifications didn't match the serialized Merkle.")
