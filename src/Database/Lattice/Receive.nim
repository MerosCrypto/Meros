#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize/SerializeReceive

#Index object.
import objects/IndexObj

#Entry object.
import objects/EntryObj

#Receive object.
import objects/ReceiveObj
export ReceiveObj

#Finals lib.
import finals

#Create a new Receive Entry.
proc newReceive*(
    index: Index,
    nonce: uint
): Receive {.raises: [ValueError, FinalAttributeError].} =
    #Verify the input address.
    if (
        (not Wallet.verify(index.address)) and
        (index.address != "minter")
    ):
        raise newException(ValueError, "Receive address is not valid.")

    #Craft the result.
    result = newReceiveObj(index)

    #Set the nonce.
    result.nonce = nonce

    #Set the hash.
    result.hash = SHA512(result.serialize())

#Sign a TX.
func sign*(
    wallet: Wallet,
    recv: Receive
) {.raises: [
    SodiumError,
    FinalAttributeError
].} =
    #Set the sender behind the Entry.
    recv.sender = wallet.address
    #Sign the hash of the Receive.
    recv.signature = wallet.sign(recv.hash.toString())
