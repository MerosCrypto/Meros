#Serialize Verification Test.

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
import ../../../../src/Network/Serialize/Consensus/SerializeVerification
import ../../../../src/Network/Serialize/Consensus/ParseVerification

#Compare Consensus lib.
import ../../../Database/Consensus/CompareConsensus

#Random standard lib.
import random

suite "SerializeVerification":
    setup:
        #Seed random.
        randomize(int64(getTime()))

    highFuzzTest "Serialize.":
        var
            #SignedVerification Element.
            verif: SignedVerification
            #Reloaded Verification Element.
            reloadedV: Verification
            #Reloaded SignedVerification Element.
            reloadedSV: SignedVerification

        #Create the SignedVerification.
        verif = newRandomVerification()

        #Serialize it and parse it back.
        reloadedV = verif.serialize().parseVerification()
        reloadedSV = verif.signedSerialize().parseSignedVerification()

        #Compare the Elements.
        compare(verif, reloadedSV)
        assert(verif.signature == reloadedSV.signature)
        compare(verif, reloadedV)

        #Test the serialized versions.
        assert(verif.serialize() == reloadedV.serialize())
        assert(verif.signedSerialize() == reloadedSV.signedSerialize())
