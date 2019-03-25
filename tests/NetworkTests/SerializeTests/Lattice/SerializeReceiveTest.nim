#Serialize Receive Tests.

#Wallet lib.
import ../../../../src/Wallet/Wallet

#Index object.
import ../../../../src/Database/common/objects/IndexObj

#Entry object.
import ../../../../src/Database/Lattice/objects/EntryObj

#Receive lib.
import ../../../../src/Database/Lattice/Receive

#Serialize lib.
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
        newIndex(
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
    assert(
        recv.descendant == recvParsed.descendant,
        "Descendant:\r\n" & $recv.descendant & "\r\n" & $recvParsed.descendant
    )
    assert(
        recv.sender == recvParsed.sender,
        "Sender:\r\n" & recv.sender & "\r\n" & recvParsed.sender
    )
    assert(
        recv.nonce == recvParsed.nonce,
        "Nonce:\r\n" & $recv.nonce & "\r\n" & $recvParsed.nonce
    )
    assert(
        recv.hash == recvParsed.hash,
        "Hash:\r\n" & $recv.hash & "\r\n" & $recvParsed.hash
    )
    assert(
        recv.signature == recvParsed.signature,
        "Signature:\r\n" & recv.signature & "\r\n" & recvParsed.signature
    )
    assert(
        recv.verified == recvParsed.verified,
        "Verified:\r\n" & $recv.verified & "\r\n" & $recvParsed.verified,
    )

    #Test the Receive properties.
    assert(
        recv.index.key == recvParsed.index.key,
        "Input Address:\r\n" & recv.index.key & "\r\n" & recvParsed.index.key
    )
    assert(
        recv.index.nonce == recvParsed.index.nonce,
        "Input Nonce:\r\n" & $recv.index.nonce & "\r\n" & $recvParsed.index.nonce
    )

echo "Finished the Network/Serialize/Lattice/Receive Test."
