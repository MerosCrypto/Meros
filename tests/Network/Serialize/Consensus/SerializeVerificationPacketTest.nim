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

    highFuzzTest "Serialize.":
        var
            #SignedVerificationPacket Element.
            packet: SignedVerificationPacket
            #Reloaded VerificationPacket Element.
            reloadedVP: VerificationPacket
            #Reloaded SignedVerificationPacket Element.
            #reloadedSVP: SignedVerificationPacket

        #Create the SignedVerificationPacket.
        packet = newRandomVerificationPacket()

        #Serialize it and parse it back.
        reloadedVP = packet.serialize().parseVerificationPacket()
        #reloadedSVP = packet.signedSerialize().parseSignedVerificationPacket()

        #Compare the Elements.
        #compare(packet, reloadedSVP)
        #assert(packet.signature == reloadedSVP.signature)
        compare(packet, reloadedVP)

        #Test the serialized versions.
        assert(packet.serialize() == reloadedVP.serialize())
        #assert(packet.signedSerialize() == reloadedSVP.signedSerialize())
