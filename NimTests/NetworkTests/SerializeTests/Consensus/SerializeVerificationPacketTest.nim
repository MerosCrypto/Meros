#Serialize Verification Packet Test.

#Util lib.
import ../../../../src/lib/Util

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Elements Testing lib.
import ../../../DatabaseTests/ConsensusTests/ElementsTests/TestElements

#Serialization libs.
import ../../../../src/Network/Serialize/Consensus/SerializeVerificationPacket
import ../../../../src/Network/Serialize/Consensus/ParseVerificationPacket

#Compare Consensus lib.
import ../../../DatabaseTests/ConsensusTests/CompareConsensus

#Random standard lib.
import random

proc test*() =
    #Seed random.
    randomize(int64(getTime()))

    var
        #SignedVerificationPacket Element.
        packet: SignedVerificationPacket
        #Reloaded VerificationPacket Element.
        reloadedVP: VerificationPacket
        #Reloaded SignedVerificationPacket Element.
        #reloadedSVP: SignedVerificationPacket

    #Test 256 serializations.
    for _ in 0 .. 255:
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

    echo "Finished the Network/Serialize/Consensus/VerificationPacket Test."
