#Serialize MemoryVerification Test.

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
import ../../../../src/Network/Serialize/Verifications/SerializeMemoryVerification
import ../../../../src/Network/Serialize/Verifications/ParseMemoryVerification

#Random standard lib.
import random

#Set the seed to be based on the time.
randomize(int(getTime()))

#Test 20 MemoryVerification serializations.
for i in 1 .. 20:
    echo "Testing MemoryVerification Serialization/Parsing, iteration " & $i & "."

    var
        #Create a Wallet for the Verifier.
        verifier: MinerWallet = newMinerWallet()
        #Create a nonce.
        nonce: uint = uint(rand(65000))
        #Create a hash.
        hash: Hash[512]
    #Set the hash to a random value.
    for i in 0 ..< 64:
        hash.data[i] = uint8(rand(255))

    #Create the MemoryVerification.
    var verif: MemoryVerification = newMemoryVerificationObj(hash)
    verifier.sign(verif, nonce)

    #Serialize it and parse it back.
    var verifParsed: MemoryVerification = verif.serialize().parseMemoryVerification()

    #Test the serialized versions.
    assert(verif.serialize() == verifParsed.serialize())

    #Test the MemoryVerification's properties.
    assert(verif.verifier == verifParsed.verifier)
    assert(verif.nonce == verifParsed.nonce)
    assert(verif.hash == verifParsed.hash)
    assert(verif.signature == verifParsed.signature)

echo "Finished the Network/Serialize/Verifications/MemoryVerification Test."
