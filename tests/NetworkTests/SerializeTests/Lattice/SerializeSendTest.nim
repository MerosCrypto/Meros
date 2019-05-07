#Serialize Send Test.

#Hash lib.
import ../../../../src/lib/Hash

#Wallet lib.
import ../../../../src/Wallet/Wallet

#Entry object.
import ../../../../src/Database/Lattice/objects/EntryObj

#Send lib.
import ../../../../src/Database/Lattice/Send

#Serialization libs.
import ../../../../src/Network/Serialize/Lattice/SerializeSend
import ../../../../src/Network/Serialize/Lattice/ParseSend

#Test 20 serializations.
for i in 1 .. 20:
    echo "Testing Send Serialization/Parsing, iteration " & $i & "."

    var
        #Wallets.
        sender: Wallet = newWallet()
        receiver: Wallet = newWallet()
        #Send (for 1 MR).
        send: Send = newSend(
            receiver.address,
            uint64(10000000000),
            0
        )
    #Sign it.
    sender.sign(send)
    #Mine the Send.
    send.mine("333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333".toHash(384))

    #Serialize it and parse it back.
    var sendParsed: Send = send.serialize().parseSend()

    #Test the serialized versions.
    assert(send.serialize() == sendParsed.serialize())

    #Test the Entry properties.
    assert(send.descendant == sendParsed.descendant)
    assert(send.sender == sendParsed.sender)
    assert(send.nonce == sendParsed.nonce)
    assert(send.hash == sendParsed.hash)
    assert(send.signature.toString() == sendParsed.signature.toString())
    assert(send.verified == sendParsed.verified)

    #Test the Send properties.
    assert(send.output == sendParsed.output)
    assert(send.amount == sendParsed.amount)
    assert(send.proof == sendParsed.proof)
    assert(send.argon == sendParsed.argon)

echo "Finished the Network/Serialize/Lattice/Send Test."
