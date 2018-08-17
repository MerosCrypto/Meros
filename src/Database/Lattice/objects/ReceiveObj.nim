#Numerical libs.
import ../../../lib/BN
import ../../../lib/Base

#Node object.
import NodeObj

#Receive object.
type Receive* = ref object of Node
    #Input address.
    inputAddress: string
    #Input nonce.
    inputNonce: BN
    #Amount transacted.
    amount: BN

#New Receive object.
proc newReceiveObj*(inputAddress: string, inputNonce: BN, amount: BN): Receive {.raises: [].} =
    Receive(
        inputAddress: inputAddress,
        inputNonce: inputNonce,
        amount: amount
    )

#Getters.
proc getInputAddress*(recv: Receive): string {.raises: [].} =
    recv.inputAddress
proc getInputNonce*(recv: Receive): BN {.raises: [].} =
    recv.inputNonce
proc getAmount*(recv: Receive): BN {.raises: [].} =
    recv.amount
