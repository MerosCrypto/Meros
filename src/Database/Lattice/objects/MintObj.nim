#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Entry object.
import EntryObj

#BN lib.
import BN

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
): Mint {.forceCheck: [].} =
    #Set the Mint fields.
    result = Mint(
        output: output,
        amount: amount
    )
    result.ffinalizeOutput()
    result.ffinalizeAmount()

    #Set the constant entry fields.
    try:
        result.sender = "minter"
        result.descendant = EntryType.Mint
        result.verified = true
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Mint: " & e.msg)
