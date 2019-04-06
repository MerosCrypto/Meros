#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#BN lib.
import BN

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet
import ../../Wallet/Address

#Import the Serialization library.
import ../../Network/Serialize/Lattice/SerializeSend

#Entry object.
import objects/EntryObj

#Send object.
import objects/SendObj
export SendObj

#Finals lib.
import finals

#Used to handle data strings.
import strutils

#Create a new Send.
proc newSend*(
    output: string,
    amount: BN,
    nonce: uint
): Send {.raises: [ValueError, FinalAttributeError].} =
    #Verify output.
    if not Address.verify(output):
        raise newException(ValueError, "Send output address is not valid.")

    #Verify the amount.
    if amount <= newBN(0):
        raise newException(ValueError, "Send amount is negative or zero.")

    #Craft the result.
    result = newSendObj(
        output,
        amount
    )

    #Set the nonce.
    result.nonce = nonce

#Sign a TX.
proc sign*(wallet: Wallet, send: Send) {.raises: [ValueError, SodiumError, FinalAttributeError].} =
    #Set the sender behind the Entry.
    send.sender = wallet.address
    #Set the hash.
    send.hash = Blake384(send.serialize())
    #Sign the hash of the Send.
    send.signature = wallet.sign(send.hash.toString())

#'Mine' a TX (beat the spam filter).
proc mine*(
    send: Send,
    networkDifficulty: BN
) {.raises: [ValueError, ArgonError, FinalAttributeError].} =
    #Make sure the hash was set.
    if send.hash.toBN() == newBN():
        raise newException(ValueError, "Send wasn't signed.")

    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    var
        proof: uint = 0
        hash: ArgonHash = Argon(send.hash.toString(), proof.toBinary(), true)

    while hash.toBN() <= networkDifficulty:
        inc(proof)
        hash = Argon(send.hash.toString(), proof.toBinary(), true)

    send.proof = proof
    send.argon = hash
