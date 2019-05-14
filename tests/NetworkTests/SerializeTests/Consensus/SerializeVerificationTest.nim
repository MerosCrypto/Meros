#Serialize Verification Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Consensus lib.
import ../../../../src/Database/Consensus/Consensus

#Serialize lib.
import ../../../../src/Network/Serialize/Consensus/SerializeVerification
import ../../../../src/Network/Serialize/Consensus/ParseVerification

#Random standard lib.
import random

#Seed Random via the time.
randomize(int(getTime()))

#Test 20 Verification serializations.
for i in 1 .. 20:
    echo "Testing Verification Serialization/Parsing, iteration " & $i & "."

    var
        #Create a Wallet for the 'MeritHolder'.
        holder: MinerWallet = newMinerWallet()
        #Create a nonce.
        nonce: uint = uint(rand(65000))
        #Create a hash.
        hash: Hash[384]
    #Set the hash to a random value.
    for i in 0 ..< 48:
        hash.data[i] = uint8(rand(255))

    #Create the Verification.
    var verif: Verification = newVerificationObj(hash)
    verif.holder = holder.publicKey
    verif.nonce = nonce

    #Serialize it and parse it back.
    var verifParsed: Verification = verif.serialize(false).parseVerification()

    #Test the serialized versions.
    assert(verif.serialize(false) == verifParsed.serialize(false))

    #Test the Verification's properties.
    assert(verif.holder == verifParsed.holder)
    assert(verif.nonce == verifParsed.nonce)
    assert(verif.hash == verifParsed.hash)

echo "Finished the Network/Serialize/Consensus/Verification Test."
