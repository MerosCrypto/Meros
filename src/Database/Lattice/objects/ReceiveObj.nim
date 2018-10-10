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
        inputNonce* {.final.}: uint

#New Receive object.
func newReceiveObj*(
    inputAddress: string,
    inputNonce: uint
): Receive {.raises: [FinalAttributeError].} =
    result = Receive(
        inputAddress: inputAddress,
        inputNonce: inputNonce
    )
    result.descendant = NodeType.Receive
