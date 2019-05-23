#Serialize Receive Tests.

#Wallet lib.
import ../../../../src/Wallet/Wallet

#LatticeIndex object.
import ../../../../src/Database/common/objects/LatticeIndexObj

#Entry object.
import ../../../../src/Database/Lattice/objects/EntryObj

#Receive lib.
import ../../../../src/Database/Lattice/Receive

#Serialization libs.
import ../../../../src/Network/Serialize/Lattice/SerializeReceive
import ../../../../src/Network/Serialize/Lattice/ParseReceive

#Test 20 serializations.
for i in 1 .. 20:
    echo "Testing Receive Serialization/Parsing, iteration " & $i & "."

    var
        #People.
        sender: string = newWallet().address
        receiver: Wallet = newWallet()
        #Receive.
        recv: Receive

    #Create the Receive.
    recv = newReceive(
        newLatticeIndex(
            sender,
            0,
        ),
        0
    )

    #Sign it.
    receiver.sign(recv)

    #Serialize it and parse it back.
    var recvParsed: Receive = recv.serialize().parseReceive()

    #Test the serialized versions.
    assert(recv.serialize() == recvParsed.serialize())

    #Test the Entry properties.
    assert(recv.descendant == recvParsed.descendant)
    assert(recv.sender == recvParsed.sender)
    assert(recv.nonce == recvParsed.nonce)
    assert(recv.hash == recvParsed.hash)
    assert(recv.signature.toString() == recvParsed.signature.toString())
    assert(recv.verified == recvParsed.verified)

    #Test the Receive properties.
    assert(recv.input.address == recvParsed.input.address)
    assert(recv.input.nonce == recvParsed.input.nonce)

echo "Finished the Network/Serialize/Lattice/Receive Test."
