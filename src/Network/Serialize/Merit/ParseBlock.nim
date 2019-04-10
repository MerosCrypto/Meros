#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#VerifierIndex object.
import ../../../Database/common/objects/VerifierIndexObj

#Miners object.
import ../../../Database/Merit/objects/MinersObj

#BlockHeader and lib.
import ../../../Database/Merit/BlockHeader
import ../../../Database/Merit/Block

#Deserialize/parse functions.
import ../SerializeCommon
import ParseBlockHeader
import ParseIndexes
import ParseMiners

#Finals lib.
import finals

#Parse a Block.
proc parseBlock*(
    blockStr: string
): Block {.raises: [
    ValueError,
    ArgonError,
    BLSError
].} =
    #Header | Verifications | Miners
    var
        header: BlockHeader = blockStr.substr(0, BLOCK_HEADER_LEN - 1).parseBlockHeader()
        indexes: seq[VerifierIndex] = blockStr.substr(
            BLOCK_HEADER_LEN,
            BLOCK_HEADER_LEN + INT_LEN + (blockStr[BLOCK_HEADER_LEN ..< BLOCK_HEADER_LEN + 4].fromBinary() * VERIFIER_INDEX_LEN)
        ).parseIndexes()
        miners: Miners = blockStr.substr(
            BLOCK_HEADER_LEN + INT_LEN + (blockStr[BLOCK_HEADER_LEN ..< BLOCK_HEADER_LEN + 4].fromBinary() * VERIFIER_INDEX_LEN)
        ).parseMiners()

    #Create the Block Object.
    result = newBlockObj(
        header.nonce,
        header.last,
        header.aggregate,
        indexes,
        miners,
        header.time,
        header.proof
    )
