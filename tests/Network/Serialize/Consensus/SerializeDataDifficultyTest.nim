#Serialize DataDifficulty Test.

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
import ../../../../src/Network/Serialize/Consensus/SerializeDataDifficulty
import ../../../../src/Network/Serialize/Consensus/ParseDataDifficulty

#Compare Consensus lib.
import ../../../Database/Consensus/CompareConsensus

#Random standard lib.
import random

suite "SerializeDataDifficulty":
    setup:
        #Seed random.
        randomize(int64(getTime()))

        var
            #SignedDataDifficulty Element.
            dataDiff: SignedDataDifficulty = newRandomDataDifficulty()
            #Reloaded DataDifficulty Element.
            reloadedDD: DataDifficulty = dataDiff.serialize().parseDataDifficulty()
            #Reloaded SignedDataDifficulty Element.
            reloadedSDD: SignedDataDifficulty = dataDiff.signedSerialize().parseSignedDataDifficulty()

    lowFuzzTest "Compare the Elements/serializations.":
        compare(dataDiff, reloadedDD)
        compare(dataDiff, reloadedSDD)
        assert(dataDiff.signature == reloadedSDD.signature)

        assert(dataDiff.serialize() == reloadedDD.serialize())
        assert(dataDiff.signedSerialize() == reloadedSDD.signedSerialize())
