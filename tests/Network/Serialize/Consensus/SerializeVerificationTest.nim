#Serialize Verification Test.

#Test lib.
import unittest

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

        var
            #SignedVerification Element.
            verif: SignedVerification = newRandomVerification()
            #Reloaded SignedVerification Element.
            reloadedSV: SignedVerification = verif.signedSerialize().parseSignedVerification()

    lowFuzzTest "Compare the Elements/serializations.":
        compare(verif, reloadedSV)
        check(verif.signature == reloadedSV.signature)

        check(verif.signedSerialize() == reloadedSV.signedSerialize())
