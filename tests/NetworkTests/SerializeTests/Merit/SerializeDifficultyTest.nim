#Serialize Difficulty Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#Difficulty object.
import ../../../../src/Database/Merit/objects/DifficultyObj

#Serialize lib.
import ../../../../src/Network/Serialize/Merit/SerializeDifficulty
import ../../../../src/Network/Serialize/Merit/ParseDifficulty

#Random standard lib.
import random

#Seed Random via the time.
randomize(getTime())

#Test 20 serializations.
for i in 1 .. 20:
    var
        start: int = rand(70000)
        endBlock: int = rand(70000)
        difficultyStr: string = ""
        difficulty: Difficulty

    for _ in 0 ..< 48:
        difficultyStr &= char(rand(255))
    difficulty = newDifficultyObj(start, endBlock, difficultyStr.toHash(384))

    echo "Testing Difficulty Serialization/Parsing, iteration " & $i & "."

    #Serialize it and parse it back.
    var difficultyParsed: Difficulty = difficulty.serialize().parseDifficulty()

    #Test the serialized versions.
    assert(difficulty.serialize() == difficultyParsed.serialize())

    #Test the start/end block.
    assert(difficulty.start == difficultyParsed.start)
    assert(difficulty.endBlock == difficultyParsed.endBlock)

    #Test the Difficulty.
    assert(difficulty.difficulty == difficultyParsed.difficulty)

echo "Finished the Network/Serialize/Merit/Difficulty Test."
