#Serialize MeritRemoval Test.

#Util lib.
import ../../../../src/lib/Util

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Elements Testing lib.
import ../../../DatabaseTests/ConsensusTests/ElementsTests/TestElements

#Serialization libs.
import ../../../../src/Network/Serialize/Consensus/SerializeMeritRemoval
import ../../../../src/Network/Serialize/Consensus/ParseMeritRemoval

#Compare Consensus lib.
import ../../../DatabaseTests/ConsensusTests/CompareConsensus

#Random standard lib.
import random

proc test*() =
    #Seed random.
    randomize(int64(getTime()))

    var
        #SignedMeritRemoval Element.
        mr: SignedMeritRemoval
        #Reloaded MeritRemoval Element.
        reloadedMR: MeritRemoval
        #Reloaded SignedMeritRemoval Element.
        reloadedSMR: SignedMeritRemoval

    #Test 256 serializations.
    for _ in 0 .. 255:
        #Create the SignedMeritRemoval.
        mr = newRandomMeritRemoval()

        #Serialize it and parse it back.
        reloadedMR = mr.serialize().parseMeritRemoval()
        reloadedSMR = mr.signedSerialize().parseSignedMeritRemoval()

        #Compare the Elements.
        compare(mr, reloadedSMR)
        assert(mr.signature == reloadedSMR.signature)
        compare(mr, reloadedMR)

        #Test the serialized versions.
        assert(mr.serialize() == reloadedMR.serialize())
        assert(mr.signedSerialize() == reloadedSMR.signedSerialize())

    echo "Finished the Network/Serialize/Consensus/MeritRemoval Test."
