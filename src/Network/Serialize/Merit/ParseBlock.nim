#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Index object.
import ../../../Database/common/objects/IndexObj

#Verifications lib.
import ../../../Database/Verifications/Verifications

#Miners object.
import ../../../Database/Merit/objects/MinersObj

#Block lib.
import ../../../Database/Merit/Block

#Deserialize/parse functions.
import ../SerializeCommon
import ParseBlockHeader
import ../Verifications/ParseVerifications
import ParseMiners

#Finals lib.
import finals

#Parse a Block.
proc parseBlock*(
    blockStr: string,
    verifs: Verifications,
): Block {.raises: [
    ValueError,
    ArgonError,
    BLSError
].} =
    #Header | Verifications | Miners
    var blockSeq: seq[string] = blockStr.deserialize(3)

    #Parse the elements.
    var
        header: BlockHeader = blockSeq[0].parseBlockHeader()
        indexes: seq[Index] = blockSeq[1].parseVerifications(verifs)
        miners: Miners = blockSeq[2].parseMiners()

    #Create the Block Object.
    result = newBlock(
        verifs,
        header.nonce,
        header.last,
        indexes,
        miners,
        header.time,
        header.proof
    )
