#Numerical libs.
import BN as BNFile
import ../../../lib/Base

#Hash lib.
import ../../../lib/Hash

#Node object.
import NodeObj

#SetOnce lib.
import SetOnce

#Send object.
type Send* = ref object of Node
    #Data used to create the SHA512 hash.
    #Destination address.
    output*: SetOnce[string]
    #Amount transacted.
    amount*: SetOnce[BN]

    #SHA512 hash.
    sha512*: SetOnce[SHA512Hash]

    #Proof this isn't spam.
    proof*: SetOnce[BN]

#New Send object.
proc newSendObj*(output: string, amount: BN): Send {.raises: [ValueError].} =
    result = Send()
    result.descendant.value = NodeType.Send
    result.output.value = output
    result.amount.value = amount
