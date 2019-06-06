#Errors lib.
import ../../lib/Errors

#Transaction lib.
import Transaction

#Send object.
import objects/SendObj
export SendObj

#Create a new Send.
func newSend*(
    inputs: seq[SendInput],
    outputs: seq[SendOutput]
): Send {.forceCheck: [
    ValueError
].} =
    #Verify the inputs length.
    if inputs.len == 0:
        raise newException(ValueError, "Send doesn't have any inputs.")

    #Verify the amounts are the same.
    var
        inputAmount: uint64 = 0
        outputAmount: uint64 = 0
    for input in inputs:
        inputAmount += input.amount
    for output in outputs:
        outputAmount += output.amount
    if inputAmount != outputAmount:
        raise newException(ValueError, "Send doesn't spend the amount it can spend.")

    #Create the result.
    result = newSendObj(
        output,
        amount
    )

    #Hash it.
    discard result.hash

#Mine the Send.
proc mine*(
    send: Send,
    networkDifficulty: Hash[384]
) {.forceCheck: [
    ValueError,
    ArgonError
].} =
    #Make sure the hash was set.
    if not send.hashed:
        raise newException(ValueError, "Send wasn't hashed.")

    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    var
        proof: int = 0
        hash: ArgonHash
    try:
        hash = Argon(send.hash.toString(), proof.toBinary(), true)
        while hash <= networkDifficulty:
            inc(proof)
            hash = Argon(send.hash.toString(), proof.toBinary(), true)
    except ArgonError as e:
        fcRaise e

    try:
        send.proof = proof
        send.argon = hash
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when mining a Send: " & e.msg)
