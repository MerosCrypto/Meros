#Serialize SignedVerification Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Consensus lib.
import ../../../../src/Database/Consensus/Consensus

#Serialize lib.
import ../../../../src/Network/Serialize/Consensus/SerializeSignedVerification
import ../../../../src/Network/Serialize/Consensus/ParseSignedVerification

#Random standard lib.
import random

#Seed Random via the time.
randomize(int(getTime()))

#Test 20 SignedVerification serializations.
for i in 1 .. 20:
    echo "Testing SignedVerification Serialization/Parsing, iteration " & $i & "."

    var
        #Create a Wallet for the MeritHolder.
        holder: MinerWallet = newMinerWallet()
        #Create a nonce.
        nonce: uint = uint(rand(65000))
        #Create a hash.
        hash: Hash[384]
    #Set the hash to a random value.
    for i in 0 ..< 48:
        hash.data[i] = uint8(rand(255))

    #Create the SignedVerification.
    var verif: SignedVerification = newSignedVerificationObj(hash)
    holder.sign(verif, nonce)

    #Serialize it and parse it back.
    var verifParsed: SignedVerification = verif.serialize().parseSignedVerification()

    #Test the serialized versions.
    assert(verif.serialize() == verifParsed.serialize())

    #Test the SignedVerification's properties.
    assert(verif.holder == verifParsed.holder)
    assert(verif.nonce == verifParsed.nonce)
    assert(verif.hash == verifParsed.hash)
    assert(verif.signature == verifParsed.signature)

echo "Finished the Network/Serialize/Consensus/SignedVerification Test."
