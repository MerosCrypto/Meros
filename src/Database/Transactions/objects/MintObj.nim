#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Transaction object.
import TransactionObj
export TransactionObj

#Mint object.
type Mint* = ref object of Transaction

#Mint constructor.
func newMintObj*(
    hash: Hash[384],
    outputs: seq[MintOutput]
): Mint {.inline, forceCheck: [].} =
    Mint(
        hash: hash,
        inputs: @[],
        outputs: cast[seq[Output]](outputs)
    )
