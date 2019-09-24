#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#BlockBody object.
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
        header = blockStr.parseBlockHeader()
        body = blockStr.substr(
            BLOCK_HEADER_LENS[0] + BLOCK_HEADER_LENS[2] + (if header.newMiner: BLS_PUBLIC_KEY_LEN else: INT_LEN)
        ).parseBlockBody()
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e

    #Create the Block Object.
    result = newBlockObj(
        header,
        body
    )
