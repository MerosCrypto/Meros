#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Send object.
import objects/SendObj
export SendObj

#Create a new Send.
proc newSend*(
    inputs: seq[SendInput],
    outputs: seq[SendOutput]
): Send {.forceCheck: [
    ValueError
].} =
    #Verify the inputs length.
    if inputs.len == 0:
        raise newException(ValueError, "Send doesn't have any inputs.")

    #Create the result.
    result = newSendObj(
        inputs,
        outputs
    )

    #Hash it.
    try:
        discard
        #result.hash = Blake384(result.serializeHash())
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Send: " & e.msg)

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
