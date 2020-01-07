#Serialize SendDifficulty Test.

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
import ../../../../src/Network/Serialize/Consensus/SerializeSendDifficulty
import ../../../../src/Network/Serialize/Consensus/ParseSendDifficulty

#Compare Consensus lib.
import ../../../Database/Consensus/CompareConsensus

#Random standard lib.
import random

suite "SerializeSendDiffculty":
    setup:
        #Seed random.
        randomize(int64(getTime()))

        var
            #SignedSendDifficulty Element.
            sendDiff: SignedSendDifficulty = newRandomSendDifficulty()
            #Reloaded SendDifficulty Element.
            reloadedSD: SendDifficulty = sendDiff.serialize().parseSendDifficulty()
            #Reloaded SignedSendDifficulty Element.
            reloadedSSD: SignedSendDifficulty = sendDiff.signedSerialize().parseSignedSendDifficulty()

    lowFuzzTest "Compare the Elements/serializations.":
        compare(sendDiff, reloadedSD)
        compare(sendDiff, reloadedSSD)
        assert(sendDiff.signature == reloadedSSD.signature)

        assert(sendDiff.serialize() == reloadedSD.serialize())
        assert(sendDiff.signedSerialize() == reloadedSSD.signedSerialize())
