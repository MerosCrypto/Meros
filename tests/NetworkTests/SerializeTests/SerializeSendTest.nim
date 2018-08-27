#Numerical libs.
import ../../../src/lib/BN
import ../../../src/lib/Base

#Wallet lib.
import ../../../src/Wallet/Wallet

#Node object, and the Send lib.
import ../../../src/Database/Lattice/objects/NodeObj
import ../../../src/Database/Lattice/Send

#Serialize lib.
import ../../../src/Network/Serialize/SerializeSend
import ../../../src/Network/Serialize/ParseSend

#Test 20 serializations.
for i in 1 .. 20:
    echo "Testing Send Serialization/Parsing, iteration " & $i & "."

    var
        #Wallets.
        sender: Wallet = newWallet()
        receiver: Wallet = newWallet()
        #Send (for 1 EMB).
        send: Send = newSend(
            receiver.getAddress(),
            newBN("10000000000"),
            newBN()
        )
    #Mine the Send.
    send.mine("3333333333333333333333333333333333333333333333333333333333333333".toBN(16))
    #Sign it.
    discard sender.sign(send)

    #Serialize it and parse it back.
    var sendParsed: Send = send.serialize().parseSend()

    #Test the serialized versions.
    assert(send.serialize() == sendParsed.serialize())

    #Test the Node properties.
    assert(send.descendant == sendParsed.descendant)
    assert(send.getSender() == sendParsed.getSender())
    assert(send.getNonce() == sendParsed.getNonce())
    assert(send.getHash() == sendParsed.getHash())
    assert(send.getSignature() == sendParsed.getSignature())

    #Test the Send properties.
    assert(send.getOutput() == sendParsed.getOutput())
    assert(send.getAmount() == sendParsed.getAmount())
    assert(send.getSHA512() == sendParsed.getSHA512())
    assert(send.getProof() == sendParsed.getProof())

echo "Finished the Network/Serialize/Receive test."
