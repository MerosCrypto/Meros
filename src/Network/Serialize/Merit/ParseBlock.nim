#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#MeritHolderRecord object.
import ../../../Database/common/objects/MeritHolderRecordObj

#Miners and BlockBody objects.
import ../../../Database/Merit/objects/MinersObj
import ../../../Database/Merit/objects/BlockBodyObj

#BlockHeader and Block libs.
import ../../../Database/Merit/BlockHeader
import ../../../Database/Merit/Block

#Deserialize/parse functions.
import ../SerializeCommon
import ParseBlockHeader
import ParseBlockBody

#Parse a Block.
proc parseBlock*(
    blockStr: string
): Block {.forceCheck: [
    ValueError,
    BLSError
].} =
    #Header | Body
    var
        header: BlockHeader
        body: BlockBody
    try:
        header = blockStr.substr(0, BLOCK_HEADER_LEN - 1).parseBlockHeader()
        body = blockStr.substr(BLOCK_HEADER_LEN).parseBlockBody()
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e

    #Create the Block Object.
    result = newBlockObj(
        header,
        body
    )
