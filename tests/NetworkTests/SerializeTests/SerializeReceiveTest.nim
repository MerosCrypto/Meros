#Serialize Receive Tests.

#Wallet lib.
import ../../../src/Wallet/Wallet

#Index and Entry object.
import ../../../src/Database/Lattice/objects/IndexObj
import ../../../src/Database/Lattice/objects/EntryObj

#Receive lib.
import ../../../src/Database/Lattice/Receive

#Serialize lib.
import ../../../src/Network/Serialize/SerializeReceive
import ../../../src/Network/Serialize/ParseReceive

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

    #Test the Receive properties.
    assert(
        recv.index.address == recvParsed.index.address,
        "Input Address:\r\n" & recv.index.address & "\r\n" & recvParsed.index.address
    )
    assert(
        recv.index.nonce == recvParsed.index.nonce,
        "Input Nonce:\r\n" & $recv.index.nonce & "\r\n" & $recvParsed.index.nonce
    )

echo "Finished the Network/Serialize/Receive test."
