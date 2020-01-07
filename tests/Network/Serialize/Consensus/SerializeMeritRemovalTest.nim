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

        var
            #SignedMeritRemoval Element.
            mr: SignedMeritRemoval = newRandomMeritRemoval()
            #Reloaded MeritRemoval Element.
            reloadedMR: MeritRemoval = mr.serialize().parseMeritRemoval()
            #Reloaded SignedMeritRemoval Element.
            reloadedSMR: SignedMeritRemoval = mr.signedSerialize().parseSignedMeritRemoval()

    highFuzzTest "Compare the Elements/serializations.":
        compare(mr, reloadedMR)
        compare(mr, reloadedSMR)
        check(mr.signature == reloadedSMR.signature)

        check(mr.serialize() == reloadedMR.serialize())
        check(mr.signedSerialize() == reloadedSMR.signedSerialize())
