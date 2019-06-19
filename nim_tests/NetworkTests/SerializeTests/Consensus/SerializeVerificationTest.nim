#Serialize Verification Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Verification lib.
import ../../../../src/Database/Consensus/Verification

#Serialization libs.
import ../../../../src/Network/Serialize/Consensus/SerializeVerification
import ../../../../src/Network/Serialize/Consensus/SerializeSignedVerification
import ../../../../src/Network/Serialize/Consensus/ParseVerification
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
    #SignedVerification Element.
    verif: SignedVerification
    #Reloaded Verification Element.
    reloadedV: Verification
    #Reloaded SignedVerification Element.
    reloadedSV: SignedVerification

#Test 256 serializations.
for _ in 0 .. 255:
    for i in 0 ..< 48:
        hash.data[i] = uint8(rand(255))

    #Create the SignedVerification.
    verif = newSignedVerificationObj(hash)
    #Sign it.
    newMinerWallet().sign(verif, rand(high(int32)))

    #Serialize it and parse it back.
    reloadedV = cast[Verification](verif).serialize().parseVerification()
    reloadedSV = verif.serialize().parseSignedVerification()

    #Test the serialized versions.
    assert(cast[Verification](verif).serialize() == reloadedV.serialize())
    assert(verif.serialize() == reloadedSV.serialize())

    #Compare the Elements.
    compare(verif, reloadedSV)
    compare(cast[Verification](verif), reloadedV)

echo "Finished the Network/Serialize/Consensus/Verification Test."
