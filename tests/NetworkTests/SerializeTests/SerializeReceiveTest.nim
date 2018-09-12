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
        sender.getAddress(),
        newBN(),
        newBN()
    )
    #Sign it.
    discard receiver.sign(recv)

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
        recv.getSender == recvParsed.getSender(),
        "Sender:\r\n" & recv.getSender() & "\r\n" & recvParsed.getSender()
    )
    assert(
        recv.getNonce() == recvParsed.getNonce(),
        "Nonce:\r\n" & $recv.getNonce() & "\r\n" & $recvParsed.getNonce()
    )
    assert(
        recv.getHash() == recvParsed.getHash(),
        "Hash:\r\n" & $recv.getHash() & "\r\n" & $recvParsed.getHash()
    )
    assert(
        recv.getSignature() == recvParsed.getSignature(),
        "Signature:\r\n" & recv.getSignature() & "\r\n" & recvParsed.getSignature()
    )

    #Test the Receive properties.
    assert(
        recv.getInputAddress() == recvParsed.getInputAddress(),
        "Input Address:\r\n" & recv.getInputAddress() & "\r\n" & recvParsed.getInputAddress()
    )
    assert(
        recv.getInputNonce() == recvParsed.getInputNonce(),
        "Input Nonce:\r\n" & $recv.getInputNonce() & "\r\n" & $recvParsed.getInputNonce()
    )

echo "Finished the Network/Serialize/Receive test."
