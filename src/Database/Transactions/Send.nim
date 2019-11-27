#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Wallet lib.
import ../../Wallet/Wallet

#Send object.
import objects/SendObj
export SendObj

#Serialization libs.
import ../../Network/Serialize/SerializeCommon
import ../../Network/Serialize/Transactions/SerializeSend

#Create a new Send.
proc newSend*(
    inputs: varargs[SendInput],
    outputs: varargs[SendOutput]
): Send {.forceCheck: [].} =
    #Create the Send.
    result = newSendObj(
        inputs,
        outputs
    )

    #Hash it.
    try:
        result.hash = Blake384(result.serializeHash())
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Send: " & e.msg)

#Sign a Send.
proc sign*(
    wallet: HDWallet,
    send: Send
) {.forceCheck: [].} =
    try:
        send.signature = wallet.sign(send.hash.toString())
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when signing a Send: " & e.msg)

#Mine the Send.
proc mine*(
    send: Send,
    networkDifficulty: Hash[384]
) {.forceCheck: [].} =
    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    var
        proof: uint32 = 0
        hash: ArgonHash = Argon(send.hash.toString(), proof.toBinary(SALT_LEN), true)
    while hash <= networkDifficulty:
        inc(proof)
        hash = Argon(send.hash.toString(), proof.toBinary(SALT_LEN), true)

    try:
        send.proof = proof
        send.argon = hash
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when mining a Send: " & e.msg)
