#Numerical libs.
import BN as BNFile
import ../../../lib/Base

#Node object.
import NodeObj

#Finals lib.
import finals

#Receive object.
finalsd:
    type Receive* = ref object of Node
        #Input address.
        inputAddress* {.final.}: string
        #Input nonce.
        inputNonce* {.final.}: BN

#New Receive object.
proc newReceiveObj*(
    inputAddress: string,
    inputNonce: BN
): Receive {.raises: [FinalAttributeError].} =
    result = Receive(
        inputAddress: inputAddress,
        inputNonce: inputNonce
    )
    result.descendant = NodeType.Receive
