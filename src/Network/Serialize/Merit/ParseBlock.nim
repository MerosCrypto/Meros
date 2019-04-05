#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#VerifierIndex object.
import ../../../Database/Merit/objects/VerifierIndexObj

#Miners object.
import ../../../Database/Merit/objects/MinersObj

#Block lib.
import ../../../Database/Merit/Block

#Deserialize/parse functions.
import ../SerializeCommon
import ParseBlockHeader
import ParseVerifications
import ParseMiners

#Finals lib.
import finals

#Parse a Block.
proc parseBlock*(
    blockStr: string
): Block {.raises: [
    ValueError,
    ArgonError,
    BLSError,
    FinalAttributeError
].} =
    #Header | Verifications | Miners
    var
        header: BlockHeader = blockStr.substr(0, BLOCK_HEADER_LEN - 1).parseBlockHeader()
        verifs: seq[VerifierIndex] = blockStr.substr(
            BLOCK_HEADER_LEN,
            BLOCK_HEADER_LEN + INT_LEN + (blockStr[BLOCK_HEADER_LEN ..< BLOCK_HEADER_LEN + 4].fromBinary() * VERIFIER_INDEX_LEN)
        ).parseVerifications()
        miners: Miners = blockStr.substr(
            BLOCK_HEADER_LEN + INT_LEN + (blockStr[BLOCK_HEADER_LEN ..< BLOCK_HEADER_LEN + 4].fromBinary() * VERIFIER_INDEX_LEN)
        ).parseMiners()

    #Create the Block Object.
    result = newBlockObj(
        header.nonce,
        header.last,
        header.verifications,
        verifs,
        miners,
        header.time,
        header.proof
    )
