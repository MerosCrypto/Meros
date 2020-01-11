#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#Hash lib.
import ../../../../../lib/Hash

#Mint object.
import ../../../..//Transactions/objects/MintObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Parse MintOutput lib.
import ParseMintOutput

#Parse function.
proc parseMint*(
    hash: Hash[256],
    mintStr: string
): Mint {.forceCheck: [].} =
    #Amount of Outputs | Outputs
    var
        outputsLen: int = mintStr[0 ..< INT_LEN].fromBinary()
        outputs: seq[MintOutput] = newSeq[MintOutput](outputsLen)

    #Parse the outputs.
    for o in 0 ..< outputsLen:
        outputs[o] = mintStr[INT_LEN + (o * MINT_OUTPUT_LEN) ..< INT_LEN + ((o + 1) * MINT_OUTPUT_LEN)].parseMintOutput()

    #Create the Mint.
    result = newMintObj(hash, outputs)
