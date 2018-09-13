#Numerical libs.
import BN as BNFile
import ../../../lib/Base

#Node object.
import NodeObj

#SetOnce lib.
import SetOnce

#Receive object.
type Receive* = ref object of Node
    #Input address.
    inputAddress*: SetOnce[string]
    #Input nonce.
    inputNonce*: SetOnce[BN]

#New Receive object.
proc newReceiveObj*(inputAddress: string, inputNonce: BN): Receive {.raises: [ValueError].} =
    result = Receive()
    result.descendant.value = NodeType.Receive
    result.inputAddress.value = inputAddress
    result.inputNonce.value = inputNonce
