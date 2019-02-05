#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet
import ../../Wallet/Address

#Import the Serialization library.
import ../../Network/Serialize/Lattice/SerializeReceive

#Index object.
import ../common/objects/IndexObj

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
    if not Address.verify(index.key):
        raise newException(ValueError, "Receive address is not valid.")

    #Craft the result.
    result = newReceiveObj(index)

    #Set the nonce.
    result.nonce = nonce

    #Set the hash.
    result.hash = Blake512(result.serialize())

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
