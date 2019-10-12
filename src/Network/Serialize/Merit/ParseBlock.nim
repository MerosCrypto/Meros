#Errors lib.
import ../../../lib/Errors

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
): tuple[
    data: Block,
    capacity: int,
    transactions: string,
    packets: string
] {.forceCheck: [
    ValueError,
    BLSError
].} =
    #Header | Body
    var
        header: BlockHeader
        body: BlockBody

    try:
        header = blockStr.parseBlockHeader()
        (body, result.capacity, result.transactions, result.packets) = blockStr.substr(
            INT_LEN + HASH_LEN + HASH_LEN + HASH_LEN + BYTE_LEN +
            INT_LEN + INT_LEN + BLS_SIGNATURE_LEN +
            (if header.newMiner: BLS_PUBLIC_KEY_LEN else: NICKNAME_LEN)
        ).parseBlockBody()
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e

    #Create the Block Object.
    result.data = newBlockObj(
        header,
        body
    )
