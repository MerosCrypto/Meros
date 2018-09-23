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

#SetOnce lib.
import SetOnce

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
            receiver.address,
            newBN("10000000000"),
            newBN()
        )
    #Mine the Send.
    send.mine("3333333333333333333333333333333333333333333333333333333333333333".toBN(16))
    #Sign it.
    assert(sender.sign(send), "Couldn't sign the Verification.")

    #Verify the Send.
    var verif: Verification = newVerification(send, BNNums.ZERO)
    verifier.sign(verif)

    #Serialize it and parse it back.
    var verifParsed: Verification = verif.serialize().parseVerification()

    #Test the serialized versions.
    assert(verif.serialize() == verifParsed.serialize())

    #Test the Node properties.
    assert(verif.descendant == verifParsed.descendant)
    assert(verif.sender == verifParsed.sender)
    assert(verif.nonce == verifParsed.nonce)
    assert(verif.hash == verifParsed.hash)
    assert(verif.signature == verifParsed.signature)

    #Test the Verification properties.
    assert(verif.verified == verifParsed.verified)

echo "Finished the Network/Serialize/Verification test."
