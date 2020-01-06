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

    highFuzzTest "Serialize and parse.":
        var
            #SignedSendDifficulty Element.
            sendDiff: SignedSendDifficulty
            #Reloaded SendDifficulty Element.
            reloadedDD: SendDifficulty
            #Reloaded SignedSendDifficulty Element.
            reloadedSDD: SignedSendDifficulty

        #Create the SignedSendDifficulty.
        sendDiff = newRandomSendDifficulty()

        #Serialize it and parse it back.
        reloadedDD = sendDiff.serialize().parseSendDifficulty()
        reloadedSDD = sendDiff.signedSerialize().parseSignedSendDifficulty()

        #Compare the Elements.
        compare(sendDiff, reloadedSDD)
        assert(sendDiff.signature == reloadedSDD.signature)
        compare(sendDiff, reloadedDD)

        #Test the serialized versions.
        assert(sendDiff.serialize() == reloadedDD.serialize())
        assert(sendDiff.signedSerialize() == reloadedSDD.signedSerialize())
