#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Lattice lib.
import ../../../Database/Lattice/Lattice

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
    blockStr: string
): Block {.raises: [
    ValueError,
    ArgonError,
    BLSError,
    FinalAttributeError
].} =
    #Header | Verifications | Miners
    var blockSeq: seq[string] = blockStr.deserialize(3)

    #Parse the elements.
    var
        header: BlockHeader = blockSeq[0].parseBlockHeader()
        verifs: seq[Index] = blockSeq[1].parseVerifications()
        miners: Miners = blockSeq[2].parseMiners()

    #Create the Block Object.
    result = newBlock(
        header.nonce,
        header.last,
        verifs,
        miners,
        header.time,
        header.proof
    )
