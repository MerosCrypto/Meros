#VerifierIndex is under common, yet serialized in a Block. Therefore, it's under Serialize/Merit.

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#VerifierIndex object.
import ../../../Database/common/objects/VerifierIndexObj

#Common serialization functions.
import ../SerializeCommon

#Serialize Indexes.
proc serialize*(indexes: seq[VerifierIndex]): string {.raises: [].} =
    #Set the quantity.
    result = indexes.len.toBinary().pad(INT_LEN)

    #Iterate over every VerifierIndex.
    for index in indexes:
        #Serialize their data.
        result &=
            index.key &
            index.nonce.toBinary().pad(INT_LEN) &
            index.merkle.toString()
