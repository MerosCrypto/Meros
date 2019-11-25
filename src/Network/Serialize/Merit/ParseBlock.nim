#Errors lib.
import ../../../lib/Errors

#BlockHeader lib.
import ../../../Database/Merit/BlockHeader

#SketchyBlock object.
import ../../objects/SketchyBlockObj

#Deserialize/parse functions.
import ../SerializeCommon
import ParseBlockHeader
import ParseBlockBody

#Parse a Block.
proc parseBlock*(
    blockStr: string
): SketchyBlock {.forceCheck: [
    ValueError,
    BLSError
].} =
    #Header | Body
    var
        header: BlockHeader
        body: SketchyBlockBody

    try:
        header = blockStr.parseBlockHeader()
        body = blockStr.substr(
            BLOCK_HEADER_DATA_LEN +
            (if header.newMiner: BLS_PUBLIC_KEY_LEN else: NICKNAME_LEN) +
            INT_LEN + INT_LEN + BLS_SIGNATURE_LEN
        ).parseBlockBody()
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e

    #Create the SketchyBlock.
    result = newSketchyBlockObj(
        header,
        body
    )
