#Serialize SendDifficulty Test.

#Util lib.
import ../../../../src/lib/Util

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Elements Testing lib.
import ../../../DatabaseTests/ConsensusTests/ElementsTests/TestElements

#Serialization libs.
import ../../../../src/Network/Serialize/Consensus/SerializeSendDifficulty
import ../../../../src/Network/Serialize/Consensus/ParseSendDifficulty

#Compare Consensus lib.
import ../../../DatabaseTests/ConsensusTests/CompareConsensus

#Random standard lib.
import random

proc test*() =
    #Seed random.
    randomize(int64(getTime()))

    var
        #SignedSendDifficulty Element.
        sendDiff: SignedSendDifficulty
        #Reloaded SendDifficulty Element.
        reloadedDD: SendDifficulty
        #Reloaded SignedSendDifficulty Element.
        reloadedSDD: SignedSendDifficulty

    #Test 256 serializations.
    for _ in 0 .. 255:
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

    echo "Finished the Network/Serialize/Consensus/SendDifficulty Test."
