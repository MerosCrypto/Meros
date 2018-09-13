#Serialize Receive Tests.

#Numerical libs.
import BN
import ../../../src/lib/Base

#Wallet lib.
import ../../../src/Wallet/Wallet

#Node object, and the Send/Receive libs.
import ../../../src/Database/Lattice/objects/NodeObj
import ../../../src/Database/Lattice/Receive

#Serialize lib.
import ../../../src/Network/Serialize/SerializeReceive
import ../../../src/Network/Serialize/ParseReceive

#SetOnce lib.
import SetOnce

#Test 20 serializations.
for i in 1 .. 20:
    echo "Testing Receive Serialization/Parsing, iteration " & $i & "."

    var
        #Wallets.
        sender: Wallet = newWallet()
        receiver: Wallet = newWallet()
        #Receive.
        recv: Receive

    #Create a Receive (based on a send that doesn't exist for 1 EMB).
    recv = newReceive(
        sender.address,
        newBN(),
        newBN()
    )
    #Sign it.
    receiver.sign(recv)

    #Serialize it and parse it back.
    var recvParsed: Receive = recv.serialize().parseReceive()

    #Test the serialized versions.
    assert(recv.serialize() == recvParsed.serialize())

    #Test the Node properties.
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
        recv.inputAddress == recvParsed.inputAddress,
        "Input Address:\r\n" & recv.inputAddress & "\r\n" & recvParsed.inputAddress
    )
    assert(
        recv.inputNonce == recvParsed.inputNonce,
        "Input Nonce:\r\n" & $recv.inputNonce & "\r\n" & $recvParsed.inputNonce
    )

echo "Finished the Network/Serialize/Receive test."
