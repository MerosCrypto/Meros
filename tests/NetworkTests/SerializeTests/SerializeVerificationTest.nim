#Serialize Verification Test.

#Numerical libs.
import BN
import ../../../src/lib/Base

#Wallet lib.
import ../../../src/Wallet/Wallet

#Node object.
import ../../../src/Database/Lattice/objects/NodeObj

#Send and Verification lib.
import ../../../src/Database/Lattice/Send
import ../../../src/Database/Lattice/Verification

#Serialize lib.
import ../../../src/Network/Serialize/SerializeVerification
import ../../../src/Network/Serialize/ParseVerification

#Test 20 serializations.
for i in 1 .. 20:
    echo "Testing Verification Serialization/Parsing, iteration " & $i & "."

    var
        #Wallets.
        sender: Wallet = newWallet()
        receiver: Wallet = newWallet()
        verifier: Wallet = newWallet()
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

    #Verify the Send.
    var verif: Verification = newVerification(send, BNNums.ZERO)
    discard verifier.sign(verif)

    #Serialize it and parse it back.
    var verifParsed: Verification = verif.serialize().parseVerification()

    #Test the serialized versions.
    assert(verif.serialize() == verifParsed.serialize())

    #Test the Node properties.
    assert(verif.descendant == verifParsed.descendant)
    assert(verif.getSender() == verifParsed.getSender())
    assert(verif.getNonce() == verifParsed.getNonce())
    assert(verif.getHash() == verifParsed.getHash())
    assert(verif.getSignature() == verifParsed.getSignature())

    #Test the Verification properties.
    assert(verif.getVerified() == verifParsed.getVerified())

echo "Finished the Network/Serialize/Verification test."
