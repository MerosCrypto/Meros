#Serialize SignedVerification Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Verification lib.
import ../../../../src/Database/Consensus/Verification

#Serialization libs.
import ../../../../src/Network/Serialize/Consensus/SerializeSignedVerification
import ../../../../src/Network/Serialize/Consensus/ParseSignedVerification

#Compare Consensus lib.
import ../../../DatabaseTests/ConsensusTests/CompareConsensus

#Random standard lib.
import random

#Seed random.
randomize(int64(getTime()))

var
    #Hash.
    hash: Hash[384]
    #Signed Verification Element.
    verif: SignedVerification
    #Reloaded Signed Verification Element.
    reloaded: SignedVerification

#Test 256 serializations.
for _ in 0 .. 255:
    for i in 0 ..< 48:
        hash.data[i] = uint8(rand(255))

    #Create the SignedVerification.
    verif = newSignedVerificationObj(hash)

    #Sign it.
    newMinerWallet().sign(verif, rand(high(int32)))

    #Serialize it and parse it back.
    reloaded = verif.serialize().parseSignedVerification()

    #Test the serialized versions.
    assert(verif.serialize() == reloaded.serialize())

    #Compare the Elements.
    compare(verif, reloaded)

echo "Finished the Network/Serialize/Consensus/SignedVerification Test."
