discard """
    This file's name is a bit of a misnomer. This file does NOT serialize the Verifications object.

    Instead, it serializes a seq[Index] (the `verifications` field in a Block object).
    This code also adds Merkles so we can see what Verifier has conflicting Verifications (if one does).
    The Aggregate Signature is enough to check validity in general, but it's not optimal for getting started on correcting the error.
"""

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

#Serialize Verifications.
proc serialize*(
    indexes: seq[Index],
    verifs: Verifications
): string {.raises: [].} =
    #Declare a seq for the hashes.
    var hashes: seq[string]

    #Iterate over every Index.
    for index in indexes:
        #Append they key and nonce to the result.
        result &=
            !index.key &
            !index.nonce.toBinary()

        #Clear hashes.
        hashes = newSeq[string](index.nonce)
        #Grab every Verificaion until this nonce, for this Verifier.
        for verif in verifs[index.key][uint(0) .. index.nonce]:
            #Add its hash to the seq.
            hashes.add(verif.hash.toString())
        #Append the Merkle hash to the result.
        result &= !newMerkle(hashes).hash
