discard """
    This file's name is a bit of a misnomer. This file does NOT serialize the Verifications object.

    Instead, it serializes a seq[VerifierIndex] (the `verifications` field in a Block object).
"""

#Util lib.
import ../../../lib/Util

#VerifierIndex object.
import ../../../Database/Merit/objects/VerifierIndexObj

#Common serialization functions.
import ../SerializeCommon

#Serialize Verifications.
proc serialize*(verifications: seq[VerifierIndex]): string {.raises: [].} =
    #Iterate over every VerifierIndex.
    for verifier in verifications:
        #Serialize their data.
        result &=
            !verifier.key &
            !verifier.nonce.toBinary() &
            !verifier.merkle
