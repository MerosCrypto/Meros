#Serialize MeritRemoval Test.

#Test lib.
import unittest2

#Fuzzing lib.
import ../../../Fuzzed

#Util lib.
import ../../../../src/lib/Util

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Elements Testing lib.
import ../../../Database/Consensus/Elements/TestElements

#Serialization libs.
import ../../../../src/Network/Serialize/Consensus/SerializeMeritRemoval
import ../../../../src/Network/Serialize/Consensus/ParseMeritRemoval

#Compare Consensus lib.
import ../../../Database/Consensus/CompareConsensus

#Random standard lib.
import random

suite "SerializeMeritRemoval":
    setup:
        #Seed random.
        randomize(int64(getTime()))

    highFuzzTest "Serialize.":
        var
            #SignedMeritRemoval Element.
            mr: SignedMeritRemoval
            #Reloaded MeritRemoval Element.
            reloadedMR: MeritRemoval
            #Reloaded SignedMeritRemoval Element.
            reloadedSMR: SignedMeritRemoval

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
