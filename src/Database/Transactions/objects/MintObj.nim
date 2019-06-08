#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Transaction object.
import TransactionObj
export TransactionObj

#Finals lib.
import finals

#Mint object.
finalsd:
    type Mint* = ref object of Transaction
        #Nonce of the Mint.
        nonce* {.final.}: int

#Mint constructor.
func newMintObj*(
    nonce: int,
    key: BLSPublicKey,
    amount: uint64
): Mint {.forceCheck: [].} =
    #Create the Mint
    result = Mint(
        nonce: nonce,
        inputs: @[],
        outputs: cast[seq[Output]](
            @[
                newMintOutput(key, amount)
            ]
        )
    )
    result.ffinalizeNonce()

    #Set the Transaction fields.
    try:
        result.descendant = TransactionType.Mint
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Mint: " & e.msg)
