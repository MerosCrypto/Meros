#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#BlockHeader object.
import ../../../Database/Merit/objects/BlockHeaderObj

#Common serialization functions.
import ../SerializeCommon

#Finals lib.
import finals

#String utils standard library.
import strutils

#Parse function.
proc parseBlockHeader*(
    headerStr: string
): BlockHeader {.raises: [ValueError, ArgonError, BLSError].} =
    #Nonce | Last Hash | Verifications Aggregate Signature | Miners Merkle | Time | Proof
    var headerSeq: seq[string] = headerStr.deserialize(
        INT_LEN,
        HASH_LEN,
        BLS_SIGNATURE_LEN,
        HASH_LEN,
        INT_LEN,
        INT_LEN
    )

    #Create the BlockHeader.
    result = newBlockHeaderObj(
        uint(headerSeq[0].fromBinary()),
        headerSeq[1].toArgonHash(),
        newBLSSignature(headerSeq[2]),
        headerSeq[3].toBlake512Hash(),
        uint(headerSeq[4].fromBinary()),
        uint(headerSeq[5].fromBinary())
    )
    result.hash = Argon(headerStr, headerSeq[5])
