#BN lib.
import BN

#Hash lib.
import ../../../lib/Hash

#Entry object.
import EntryObj

#Finals lib.
import finals

#Send object.
finalsd:
    type Send* = ref object of Entry
        #Data used to create the Blake512 hash.
        #Destination address.
        output* {.final.}: string
        #Amount transacted.
        amount* {.final.}: BN

        #Proof this isn't spam.
        proof* {.final.}: uint
        #Argon hash.
        argon* {.final.}: ArgonHash

#New Send object.
func newSendObj*(
    output: string,
    amount: BN
): Send {.raises: [FinalAttributeError].} =
    result = Send(
        output: output,
        amount: amount
    )
    result.ffinalizeOutput()
    result.ffinalizeAmount()

    result.descendant = EntryType.Send
