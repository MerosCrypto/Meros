#Errors lib.
import ../../../lib/Errors

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
    FinalAttributeError,
].} =
    #Header | Verifications | Miners
    var blockSeq: seq[string] = blockStr.deserialize(3)

    #Parse the elements.
    var
        header: BlockHeader = blockSeq[0].parseBlockHeader()
        verifs: seq[VerifierIndex] = blockSeq[1].parseVerifications()
        miners: Miners = blockSeq[2].parseMiners()

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
