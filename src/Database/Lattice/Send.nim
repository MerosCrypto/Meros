#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Address
import ../../Wallet/Wallet

#Entry object.
import objects/EntryObj

#Send object.
import objects/SendObj
export SendObj

#Import the Serialization library.
import ../../Network/Serialize/Lattice/SerializeSend

#BN lib.
import BN

#Create a new Send.
func newSend*(
    output: string,
    amount: BN,
    nonce: Natural
): Send {.forceCheck: [
    ValueError,
    AddressError
].} =
    #Verify output.
    if not Address.isValid(output):
        raise newException(AddressError, "Send output address is not valid.")

    #Verify the amount.
    if amount <= newBN(0):
        raise newException(ValueError, "Send amount is negative or zero.")

    #Create the result.
    result = newSendObj(
        output,
        amount
    )

    #Set the nonce.
    try:
        result.nonce = nonce
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Send: " & e.msg)

#Sign a Send.
proc sign*(
    wallet: Wallet,
    send: Send
) {.forceCheck: [
    AddressError,
    SodiumError
].} =
    try:
        #Set the sender behind the Entry.
        send.sender = wallet.address
        #Set the hash.
        send.hash = Blake384(send.serialize())
        #Sign the hash of the Send.
        send.signature = wallet.sign(send.hash.toString())
        send.signed = true
    except AddressError as e:
        fcRaise e
    except SodiumError as e:
        fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when signing a Send: " & e.msg)

#'Mine' a TX (beat the spam filter).
proc mine*(
    send: Send,
    networkDifficulty: BN
) {.forceCheck: [
    ValueError,
    ArgonError
].} =
    #Make sure the hash was set.
    if send.hash.toBN() == newBN():
        raise newException(ValueError, "Send wasn't signed.")

    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    var
        proof: int = 0
        hash: ArgonHash
    try:
        hash = Argon(send.hash.toString(), proof.toBinary(), true)
        while hash.toBN() <= networkDifficulty:
            inc(proof)
            hash = Argon(send.hash.toString(), proof.toBinary(), true)
    except ArgonError as e:
        fcRaise e

    try:
        send.proof = proof
        send.argon = hash
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when mining a Send: " & e.msg)
