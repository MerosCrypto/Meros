import ../../lib/[Errors, Hash]

import objects/MintObj
export MintObj

proc newMint*(
  hash: Hash[256],
  outputs: seq[MintOutput]
): Mint {.inline, forceCheck: [].} =
  newMintObj(hash, outputs)
