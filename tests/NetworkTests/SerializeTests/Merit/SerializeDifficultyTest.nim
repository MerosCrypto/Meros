#Serialize Difficulty Test.

#Numerical libs.
import BN
import ../../../../src/lib/Base

#Difficulty object.
import ../../../../src/Database/Merit/objects/DifficultyObj

#Serialize lib.
import ../../../../src/Network/Serialize/Merit/SerializeDifficulty
import ../../../../src/Network/Serialize/Merit/ParseDifficulty

#Random/times standard lib.
import random
import times

import strutils

#Set the seed to be based on the time.
randomize(getTime().toUnix())

#Test 20 serializations.
for i in 1 .. 20:
    var
        start: uint = uint(rand(70000))
        endBlock: uint = uint(rand(70000))
        difficultyStr: string = ""
        difficulty: Difficulty

    for _ in 0 ..< 64:
        difficultyStr &= rand(255)
    difficulty = newDifficultyObj(start, endBlock, difficultyStr.toBN(256))

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
