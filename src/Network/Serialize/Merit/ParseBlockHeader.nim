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
): BlockHeader {.raises: [ValueError, BLSError, FinalAttributeError].} =
    #Nonce | Last Hash | Verifications Aggregate Signature | Miners Merkle | Time
    var headersSeq: seq[string] = headerStr.deserialize(5)

    #Create the BlockHeader.
    result = BlockHeader(
        verifications: newBLSSignature(headersSeq[1].pad(96)),
        miners: headersSeq[2].pad(64).toSHA512Hash(),
        time: uint(headersSeq[3].fromBinary())
    )
    #Set the fields marked final we couldn't set inside the constructor.
    result.nonce = uint(headersSeq[0].fromBinary())
    result.last = headersSeq[0].pad(64).toArgonHash()
