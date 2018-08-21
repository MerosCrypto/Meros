#Numerical libs.
import ../../../src/lib/BN
import ../../../src/lib/Base

#Wallet lib.
import ../../../src/Wallet/Wallet

#Node object, and the Send/Receive libs.
import ../../../src/Database/Lattice/objects/NodeObj
import ../../../src/Database/Lattice/Receive

#Serialize lib.
import ../../../src/Network/Serialize

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
        newBN("10000000000"),
        newBN()
    )
    #Sign it.
    discard receiver.sign(recv)

    #Serialize it and parse it back.
    var recvParsed: Receive = recv.serialize().parseReceive()

    #Test the Node properties.
    assert(
        recv.getDescendant() == recvParsed.getDescendant(),
        "Descendant:\r\n" & $recv.getDescendant() & "\r\n\r\n" & $recvParsed.getDescendant()
    )
    assert(
        recv.getSender == recvParsed.getSender(),
        "Sender:\r\n" & recv.getSender() & "\r\n\r\n" & recvParsed.getSender()
    )
    assert(
        recv.getNonce() == recvParsed.getNonce(),
        "Nonce:\r\n" & $recv.getNonce() & "\r\n\r\n" & $recvParsed.getNonce()
    )
    assert(
        recv.getHash() == recvParsed.getHash(),
        "Hash:\r\n" & recv.getHash() & "\r\n\r\n" & recvParsed.getHash()
    )
    assert(
        recv.getSignature() == recvParsed.getSignature(),
        "Signature:\r\n" & recv.getSignature() & "\r\n\r\n" & recvParsed.getSignature()
    )

    #Test the Receive properties.
    assert(
        recv.getInputAddress() == recvParsed.getInputAddress(),
        "Input Address:\r\n" & recv.getInputAddress() & "\r\n\r\n" & recvParsed.getInputAddress()
    )
    assert(
        recv.getInputNonce() == recvParsed.getInputNonce(),
        "Input Nonce:\r\n" & $recv.getInputNonce() & "\r\n\r\n" & $recvParsed.getInputNonce()
    )
    assert(
        recv.getAmount() == recvParsed.getAmount(),
        "Amount:\r\n" & $recv.getAmount() & "\r\n\r\n" & $recvParsed.getAmount()
    )

echo "Finished the Network/Serialize/Receive test."
