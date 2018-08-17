#Numerical libs.
import ../../../lib/BN
import ../../../lib/Base

#Node object.
import NodeObj

#Send object.
type Send* = ref object of Node
    #Data used to create the SHA512 hash.
    #Destination address.
    output: string
    #Amount transacted.
    amount: BN

    #SHA512 hash.
    sha512: string

    #Proof this isn't spam.
    proof: BN

#New Send object.
proc newSendObj*(output: string, amount: BN): Send {.raises: [].} =
    Send(
        output: output,
        amount: amount
    )

#Set the SHA512 hash.
proc setSHA512*(send: Send, sha512: string): bool =
    result = true
    if send.sha512.len != 0:
        result = false
        return

    send.sha512 = sha512

#Set the proof.
proc setProof*(send: Send, proof: BN): bool =
    result = true
    if not send.proof.isNil:
        result = false
        return

    send.proof = proof

#Getters.
proc getOutput*(send: Send): string {.raises: [].} =
    send.output
proc getAmount*(send: Send): BN {.raises: [].} =
    send.amount
proc getSHA512*(send: Send): string {.raises: [].} =
    send.sha512
proc getProof*(send: Send): BN {.raises: [].} =
    send.proof
