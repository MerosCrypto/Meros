import ../../../lib/[Errors, Hash]

import TransactionObj
export TransactionObj

type Mint* = ref object of Transaction

func newMintObj*(
  hash: Hash[256],
  outputs: seq[MintOutput]
): Mint {.inline, forceCheck: [].} =
  Mint(
    hash: hash,
    inputs: @[],
    outputs: cast[seq[Output]](outputs)
  )
