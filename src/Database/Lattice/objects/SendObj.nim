#Numerical libs.
import BN as BNFile
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#Node object.
import NodeObj

#Finals lib.
import finals

#Send object.
finalsd:
    type Send* = ref object of Node
        #Data used to create the SHA512 hash.
        #Destination address.
        output* {.final.}: string
        #Amount transacted.
        amount* {.final.}: BN

        #SHA512 hash.
        sha512* {.final.}: SHA512Hash
        #Proof this isn't spam.
        proof* {.final.}: BN

#New Send object.
func newSendObj*(
    output: string,
    amount: BN
): Send {.raises: [FinalAttributeError].} =
    result = Send(
        output: output,
        amount: amount
    )
    result.descendant = NodeType.Send
