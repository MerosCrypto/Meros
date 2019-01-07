#Serialize Verification Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#BLS lib.
import ../../../../src/lib/BLS

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Verifications lib.
import ../../../../src/Database/Verifications/Verifications

#Serialize lib.
import ../../../../src/Network/Serialize/Verifications/SerializeVerifications
import ../../../../src/Network/Serialize/Verifications/ParseVerifications

#Random standard lib.
import random

#Set the seed to be based on the time.
randomize(int(getTime()))

discard """
#Test 20 Verification serializations.
for i in 1 .. 20:
    echo "Testing Verification Serialization/Parsing, iteration " & $i & "."

    var
        #Create a Wallet for signing the Verification.
        verifier: MinerWallet = newMinerWallet()
        #Create a hash.
        hash: Hash[512]
    #Set the hash to a random value.
    for i in 0 ..< 64:
        hash.data[i] = uint8(rand(255))
    #Add the Verification.
    var verif: MemoryVerification = newMemoryVerification(hash)
    verifier.sign(verif)

    #Serialize it and parse it back.
    var verifParsed: MemoryVerification = verif.serialize().parseVerification()

    #Test the serialized versions.
    assert(verif.serialize() == verifParsed.seriMeritalize())

    #Test the Verification's properties.
    assert(verif.verifier == verifParsed.verifier)
    assert(verif.hash == verifParsed.hash)
    assert(verif.signature == verifParsed.signature)

#Test 20 Verifications serializations.
for i in 1 .. 20:
    echo "Testing Verifications Serialization/Parsing, iteration " & $i & "."

    var
        #Verifications.
        verifs: Verifications = newVerificationsObj()
        #Verification quantity.
        verifQuantity: int = rand(200) + 1

    #Fill up the Verifications.
    for v in 0 ..< verifQuantity:
        var
            #Random hash to verify.
            hash: Hash[512]
            #Verifier.
            verifier: MinerWallet = newMinerWallet()
            #Verification.
            verif: MemoryVerification

        #Randomize the hash.
        for b in 0 ..< 64:
            hash.data[b] = uint8(rand(255))

        #Create the Verification.
        verif = newMemoryVerification(hash)
        verifier.sign(verif)
        verifs.verifications.add(verif)

    #Calculate the Verifications sig.
    verifs.calculateSig()

    #Serialize it and parse it back.
    var verifsParsed: Verifications = verifs.serialize().parseVerifications(verifs.aggregate)

    #Test the serialized versions.
    assert(verifs.serialize() == verifsParsed.serialize())

    #Test the Verifications.
    for v in 0 ..< verifs.verifications.len:
        assert(verifs.verifications[v].verifier == verifsParsed.verifications[v].verifier)
        assert(verifs.verifications[v].hash == verifsParsed.verifications[v].hash)
    assert(verifs.aggregate == verifsParsed.aggregate)

echo "Finished the Network/Serialize/Merit/Verifications test."
"""
