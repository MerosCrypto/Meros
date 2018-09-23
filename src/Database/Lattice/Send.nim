#Errors lib.
import ../../lib/Errors

#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize/SerializeSend

#Node object.
import objects/NodeObj

#Send object.
import objects/SendObj
export SendObj

#SetOnce lib.
import SetOnce

#Used to handle data strings.
import strutils

#Create a new  node.
proc newSend*(
    output: string,
    amount: BN,
    nonce: BN
): Send {.raises: [ValueError].} =
    #Verify output.
    if not Wallet.verify(output):
        raise newException(ValueError, "Send output address is not valid.")

    #Verify the amount.
    if amount < BNNums.ZERO:
        raise newException(ValueError, "Send amount is negative.")

    #Craft the result.
    result = newSendObj(
        output,
        amount
    )

    #Set the nonce.
    result.nonce.value = nonce

    #Set the SHA512.
    result.sha512.value = SHA512(result.serialize())

#'Mine' a TX (beat the spam filter).
proc mine*(send: Send, networkDifficulty: BN) {.raises: [ResultError, ValueError].} =
    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    var
        proof: BN = newBN()
        hash: ArgonHash = Argon(send.sha512.toString(), proof.toString(256), true)

    while hash.toBN() <= networkDifficulty:
        inc(proof)
        hash = Argon(send.sha512.toString(), proof.toString(256), true)

    send.proof.value = proof
    send.hash.value = hash

#Sign a TX.
proc sign*(wallet: Wallet, send: Send): bool {.raises: [ValueError].} =
    result = true

    #Make sure the proof exists.
    if send.proof.getNil():
        return false
    #Set the sender behind the node.
    send.sender.value = wallet.address
    #Sign the hash of the Send.
    send.signature.value = wallet.sign($send.hash.toValue())
