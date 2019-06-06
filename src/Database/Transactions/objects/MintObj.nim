#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Transaction object.
import TransactionObj

#Finals lib.
import finals

#Mint object.
finalsd:
    type Mint* = ref object of Transaction'
        #Nonce of the Mint.
        nonce: int

#Mint constructor.
func newMintObj*(
    nonce: int,
    key: BLSPublicKey,
    amount: uint64
): Mint {.forceCheck: [].} =
    #Create the Mint
    result = Mint(
        nonce: nonce
    )

    #Set the Transaction fields.
    try:
        result.descendant = TransactionType.Mint
        result.inputs = @[]
        result.outputs = @[
            MintOutput(
                key: key,
                amount: amount
            )
        ]
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Mint: " & e.msg)
