import ../../../../../lib/[Errors, Util, Hash]

import ../../../../Transactions/objects/MintObj

import ../../../../../Network/Serialize/SerializeCommon
import ParseMintOutput

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

  result = newMintObj(hash, outputs)
