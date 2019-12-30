#Serialize DataDifficulty Test.

#Util lib.
import ../../../../src/lib/Util

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Elements Testing lib.
import ../../../DatabaseTests/ConsensusTests/ElementsTests/TestElements

#Serialization libs.
import ../../../../src/Network/Serialize/Consensus/SerializeDataDifficulty
import ../../../../src/Network/Serialize/Consensus/ParseDataDifficulty

#Compare Consensus lib.
import ../../../DatabaseTests/ConsensusTests/CompareConsensus

#Random standard lib.
import random

proc test*() =
    #Seed random.
    randomize(int64(getTime()))

    var
        #SignedDataDifficulty Element.
        dataDiff: SignedDataDifficulty
        #Reloaded DataDifficulty Element.
        reloadedDD: DataDifficulty
        #Reloaded SignedDataDifficulty Element.
        reloadedSDD: SignedDataDifficulty

    #Test 256 serializations.
    for _ in 0 .. 255:
        #Create the SignedDataDifficulty.
        dataDiff = newRandomDataDifficulty()

        #Serialize it and parse it back.
        reloadedDD = dataDiff.serialize().parseDataDifficulty()
        reloadedSDD = dataDiff.signedSerialize().parseSignedDataDifficulty()

        #Compare the Elements.
        compare(dataDiff, reloadedSDD)
        assert(dataDiff.signature == reloadedSDD.signature)
        compare(dataDiff, reloadedDD)

        #Test the serialized versions.
        assert(dataDiff.serialize() == reloadedDD.serialize())
        assert(dataDiff.signedSerialize() == reloadedSDD.signedSerialize())

    echo "Finished the Network/Serialize/Consensus/DataDifficulty Test."
