#Serialize Verification Test.

#Hash lib.
import ../../../src/lib/Hash

#Wallet lib.
import ../../../src/Wallet/Wallet

#Verification lib.
import ../../../src/Database/Merit/Verification

#Serialize lib.
import ../../../src/Network/Serialize/SerializeVerification
import ../../../src/Network/Serialize/ParseVerification

#Random standard lib.
import random

#Test 20 serializations.
for i in 1 .. 20:
    echo "Testing Verification Serialization/Parsing, iteration " & $i & "."

    var
        #Create a Wallet for signing the Verification.
        verifier: Wallet = newWallet()
        #Create a hash.
        hash: Hash[512]
    #Set the hash to a random vaue.
    for i in 0 ..< 64:
        hash.data[i] = uint8(rand(255))

    #Verify the Verification.
    var verif: MemoryVerification = newMemoryVerification(hash)
    verifier.sign(verif)

    #Serialize it and parse it back.
    var verifParsed: MemoryVerification = verif.serialize().parseVerification()

    #Test the serialized versions.
    assert(verif.serialize() == verifParsed.serialize())

    #Test the Verification's properties.
    assert(verif.sender == verifParsed.sender)
    assert(verif.hash == verifParsed.hash)
    assert(verif.edSignature == verifParsed.edSignature)

echo "Finished the Network/Serialize/Verification test."
