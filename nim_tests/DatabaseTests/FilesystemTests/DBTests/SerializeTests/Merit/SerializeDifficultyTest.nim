#Serialize Difficulty Test.

#Util lib.
import ../../../../../../src/lib/Util

#Hash lib.
import ../../../../../../src/lib/Hash

#Difficulty object.
import ../../../../../../src/Database/Merit/objects/DifficultyObj

#Serialize libs.
import ../../../../../../src/Database/Filesystem/DB/Serialize/Merit/SerializeDifficulty
import ../../../../../../src/Database/Filesystem/DB/Serialize/Merit/ParseDifficulty

#Compare Merit lib.
import ../../../../MeritTests/CompareMerit

#StInt.
import StInt

#Random standard lib.
import random

proc test*() =
    #Seed Random via the time.
    randomize(int64(getTime()))

    var
        #Difficulty value.
        value: string
        #Difficulty.
        difficulty: Difficulty
        #Reloaded Difficulty.
        reloaded: Difficulty

    #Test 255 serializations.
    for s in 0 .. 255:
        #Randomize the value.
        value = "".pad(16)
        for _ in 0 ..< 48:
            value &= char(rand(255))

        #Create the Difficulty.
        difficulty = newDifficultyObj(
            rand(high(int32)),
            rand(high(int32)),
            value.toHex().parse(StUint[512], 16)
        )

        #Serialize it and parse it back.
        reloaded = difficulty.serialize().parseDifficulty()

        #Test the serialized versions.
        assert(difficulty.serialize() == reloaded.serialize())

        #Compare the Difficulty.
        compare(difficulty, reloaded)

    echo "Finished the Database/Filesystem/DB/Serialize/Merit/Difficulty Test."
