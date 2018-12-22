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
    #Nonce | Last Hash | Verifications Aggregate Signature | Miners Merkle | Time
    var headersSeq: seq[string] = headerStr.deserialize(5)

    #Create the BlockHeader.
    result = newBlockHeaderObj(
        uint(headersSeq[0].fromBinary()),
        headersSeq[1].pad(64).toArgonHash(),
        newBLSSignature(headersSeq[2].pad(96)),
        headersSeq[3].pad(64).toSHA512Hash(),
        uint(headersSeq[4].fromBinary())
    )
