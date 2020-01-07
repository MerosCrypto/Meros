#Serialize Verification Packet Test.

#Test lib.
import unittest2

#Fuzzing lib.
import ../../../Fuzzed

#Util lib.
import ../../../../src/lib/Util

#Elements Testing lib.
import ../../../Database/Consensus/Elements/TestElements

#Serialization libs.
import ../../../../src/Network/Serialize/Consensus/SerializeVerificationPacket
import ../../../../src/Network/Serialize/Consensus/ParseVerificationPacket

#Compare Consensus lib.
import ../../../Database/Consensus/CompareConsensus

#Random standard lib.
import random

suite "SerializeVerificationPacket":
    setup:
        #Seed random.
        randomize(int64(getTime()))

        var
            #SignedVerificationPacket Element.
            packet: SignedVerificationPacket = newRandomVerificationPacket()
            #Reloaded VerificationPacket Element.
            reloadedVP: VerificationPacket = packet.serialize().parseVerificationPacket()

    midFuzzTest "Compare the Elements/serializations.":
        compare(packet, reloadedVP)

        assert(packet.serialize() == reloadedVP.serialize())
