#Serialize Verification Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#Verification object.
import ../../../../src/Database/Consensus/objects/VerificationObj

#Serialization libs.
import ../../../../src/Network/Serialize/Consensus/SerializeVerification
import ../../../../src/Network/Serialize/Consensus/ParseVerification

#Compare Consensus lib.
import ../../../DatabaseTests/ConsensusTests/CompareConsensus

#Random standard lib.
import random

#Seed random.
randomize(int64(getTime()))

var
    #Hash.
    hash: Hash[384]
    #Verification Element.
    verif: Verification
    #Reloaded Verification Element.
    reloaded: Verification

#Test 256 serializations.
for _ in 0 .. 255:
    for i in 0 ..< 48:
        hash.data[i] = uint8(rand(255))

    #Create the Verification.
    verif = newVerificationObj(hash)

    #Serialize it and parse it back.
    reloaded = verif.serialize().parseVerification()

    #Test the serialized versions.
    assert(verif.serialize() == reloaded.serialize())

    #Compare the Elements.
    compare(verif, reloaded)

echo "Finished the Network/Serialize/Consensus/Verification Test."
