#Numerical libs.
import BN
import ../../../lib/Base

#Node object.
import NodeObj

#Receive object.
type Receive* = ref object of Node
    #Input address.
    inputAddress: string
    #Input nonce.
    inputNonce: BN

#New Receive object.
proc newReceiveObj*(inputAddress: string, inputNonce: BN): Receive {.raises: [].} =
    Receive(
        descendant: NodeType.Receive,
        inputAddress: inputAddress,
        inputNonce: inputNonce
    )

#Getters.
proc getInputAddress*(recv: Receive): string {.raises: [].} =
    recv.inputAddress
proc getInputNonce*(recv: Receive): BN {.raises: [].} =
    recv.inputNonce
