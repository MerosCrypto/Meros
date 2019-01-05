#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Miners object.
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
): BlockHeader {.raises: [ValueError, BLSError].} =
    #Nonce | Last Hash | Verifications Aggregate Signature | Miners Merkle | Time | Proof
    var headerSeq: seq[string] = headerStr.deserialize(6)

    #Create the BlockHeader.
    result = newBlockHeaderObj(
        uint(headerSeq[0].fromBinary()),
        headerSeq[1].pad(64).toArgonHash(),
        newBLSSignature(headerSeq[2].pad(96)),
        headerSeq[3].pad(64).toSHA512Hash(),
        uint(headerSeq[4].fromBinary()),
        uint(headerSeq[5].toBinary())
    )
