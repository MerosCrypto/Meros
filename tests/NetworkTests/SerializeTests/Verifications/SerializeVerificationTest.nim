#Serialize Verification Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#BLS/MinerWallet libs.
import ../../../../src/lib/BLS
import ../../../../src/Wallet/MinerWallet

#Verifications lib.
import ../../../../src/Database/Verifications/Verifications

#Serialize lib.
import ../../../../src/Network/Serialize/Verifications/SerializeVerification
import ../../../../src/Network/Serialize/Verifications/ParseVerification

#Random standard lib.
import random

#Set the seed to be based on the time.
randomize(int(getTime()))

#Test 20 Verification serializations.
for i in 1 .. 20:
    echo "Testing Verification Serialization/Parsing, iteration " & $i & "."

    var
        #Create a Wallet for the 'Verifier'.
        verifier: MinerWallet = newMinerWallet()
        #Create a nonce.
        nonce: uint = uint(rand(65000))
        #Create a hash.
        hash: Hash[512]
    #Set the hash to a random value.
    for i in 0 ..< 64:
        hash.data[i] = uint8(rand(255))

    #Create the Verification.
    var verif: Verification = newVerificationObj(hash)
    verif.verifier = verifier.publicKey
    verif.nonce = nonce

    #Serialize it and parse it back.
    var verifParsed: Verification = verif.serialize().parseVerification()

    #Test the serialized versions.
    assert(verif.serialize() == verifParsed.serialize())

    #Test the Verification's properties.
    assert(verif.verifier == verifParsed.verifier)
    assert(verif.nonce == verifParsed.nonce)
    assert(verif.hash == verifParsed.hash)

echo "Finished the Network/Serialize/Verifications/Verification Test."
