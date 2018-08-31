#Errors lib.
import ../../lib/Errors

#Numerical libs.
import BN
import ../../lib/Base

#Hashing libs.
import ../../lib/SHA512
import ../../lib/Argon

#Wallet libs.
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize/SerializeSend

#Node object.
import objects/NodeObj

#Send object.
import objects/SendObj
export SendObj

#Used to handle data strings.
import strutils

#Create a new  node.
proc newSend*(
    output: string,
    amount: BN,
    nonce: BN
): Send {.raises: [ResultError, ValueError, Exception].} =
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
    if not result.setNonce(nonce):
        raise newException(ResultError, "Setting the Send nonce failed.")

    #Set the hash.
    if not result.setSHA512(SHA512(result.serialize())):
        raise newException(ResultError, "Couldn't set the Send SHA512.")

#'Mine' a TX (beat the spam filter).
proc mine*(send: Send, networkDifficulty: BN) {.raises: [ResultError, ValueError].} =
    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    var
        proof: BN = newBN()
        hash: string = "00"

    while hash.toBN(16) <= networkDifficulty:
        inc(proof)
        hash = Argon(send.getSHA512(), proof.toString(16), true)

    if send.setProof(proof) == false:
        raise newException(ResultError, "Couldn't set the Send proof.")
    if send.setHash(hash) == false:
        raise newException(ResultError, "Couldn't set the Send hash.")

#Sign a TX.
proc sign*(wallet: Wallet, send: Send): bool {.raises: [ValueError].} =
    result = true

    #Make sure the proof exists.
    if send.getProof().getNil():
        return false

    #Set the sender behind the node.
    if not send.setSender(wallet.getAddress()):
        return false

    #Sign the hash of the Send.
    if not send.setSignature(wallet.sign(send.getHash())):
        return false
