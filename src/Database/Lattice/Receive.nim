#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Address
import ../../Wallet/Wallet

#LatticeIndex object.
import ../common/objects/LatticeIndexObj

#Entry object.
import objects/EntryObj

#Receive object.
import objects/ReceiveObj
export ReceiveObj

#Import the Serialization library.
import ../../Network/Serialize/Lattice/SerializeReceive

#Create a new Receive Entry.
proc newReceive*(
    index: LatticeIndex,
    nonce: Natural
): Receive {.forceCheck: [
    AddressError
].} =
    #Verify the input address.
    if not Address.isValid(index.address):
        raise newException(AddressError, "Receive address is not valid.")

    #Create the result.
    result = newReceiveObj(index)

    try:
        #Set the nonce.
        result.nonce = nonce
        #Set the hash.
        result.hash = Blake384(result.serialize())
    except AddressError as e:
        fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Receive: " & e.msg)

#Sign a Receive.
func sign*(
    wallet: Wallet,
    recv: Receive
) {.forceCheck: [
    SodiumError
].} =
    try:
        #Set the sender behind the Entry.
        recv.sender = wallet.address
        #Sign the hash of the Receive.
        recv.signature = wallet.sign(recv.hash.toString())
        recv.signed = true
    except SodiumError as e:
        fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when signing a Receive: " & e.msg)
