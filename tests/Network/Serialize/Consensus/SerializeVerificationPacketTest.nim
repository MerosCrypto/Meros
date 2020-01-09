#Serialize Verification Packet Test.

#Test lib.
import unittest2

#Fuzzing lib.
import ../../../Fuzzed

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

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

    highFuzzTest "VerificationPacket with 256 holders.":
        var hash: Hash[384]
        for b in 0 ..< 48:
            hash.data[b] = uint8(rand(255))

        var packet: VerificationPacket = newVerificationPacketObj(hash)
        packet.holders = newSeq[uint16](256)
        var reloaded: VerificationPacket = packet.serialize().parseVerificationPacket()

        assert(packet.serialize()[0] == char(1))
        compare(packet, reloaded)
        check(packet.serialize() == reloaded.serialize())

    midFuzzTest "Compare the Elements/serializations.":
        var
            #SignedVerificationPacket Element.
            packet: SignedVerificationPacket = newRandomVerificationPacket()
            #Reloaded VerificationPacket Element.
            reloaded: VerificationPacket = packet.serialize().parseVerificationPacket()

        compare(packet, reloaded)
        check(packet.serialize() == reloaded.serialize())
