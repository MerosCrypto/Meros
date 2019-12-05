#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Transaction object.
import TransactionObj
export TransactionObj

#Finals lib.
import finals

#Mint object.
type Mint* = ref object of Transaction

#Mint constructor.
func newMintObj*(
    hash: Hash[384],
    outputs: seq[MintOutput]
): Mint {.forceCheck: [].} =
    result = Mint(
        inputs: @[],
        outputs: cast[seq[Output]](outputs)
    )

    try:
        result.hash = hash
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when constructing a Mint: " & e.msg)
