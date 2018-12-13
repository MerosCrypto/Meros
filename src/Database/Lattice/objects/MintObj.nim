#BN lib.
import BN

#Hash lib.
import ../../../lib/Hash

#Entry object.
import EntryObj

#Finals lib.
import finals

#Mint object.
finalsd:
    type Mint* = ref object of Entry
        #Destination address.
        output* {.final.}: string
        #Amount transacted.
        amount* {.final.}: BN

#Constructor.
func newMintObj*(
    output: string,
    amount: BN
): Mint {.raises: [FinalAttributeError].} =
    #Set the Mint fields.
    result = Mint(
        output: output,
        amount: amount
    )
    result.ffinalizeOutput()
    result.ffinalizeAmount()

    #Set the constant entry fields.
    result.sender = "minter"
    result.descendant = EntryType.Mint
    result.verified = true
