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

#Send object.
finalsd:
    type Send* = ref object of Entry
        #Data used to create the Blake384 hash.
        #Destination address.
        output* {.final.}: string
        #Amount transacted.
        amount* {.final.}: BN

        #Proof this isn't spam.
        proof* {.final.}: int
        #Argon hash.
        argon* {.final.}: ArgonHash

#New Send object.
func newSendObj*(
    output: string,
    amount: BN
): Send {.forceCheck: [].} =
    result = Send(
        output: output,
        amount: amount
    )
    result.ffinalizeOutput()
    result.ffinalizeAmount()

    try:
        result.descendant = EntryType.Send
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Mint: " & e.msg)
