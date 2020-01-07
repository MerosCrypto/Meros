#Spam Filter Test.

#Test lib.
import unittest2

#Fuzzing lib.
import ../../Fuzzed

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#SpamFilter object.
import ../../../src/Database/Consensus/objects/SpamFilterObj

#Random standard lib.
import random

#Seq utils standard lib.
import sequtils

#String utils standard lib.
import strutils

#Algorithm standard lib.
import algorithm

#Tables standard lib.
import tables

const
    #Starting difficulty.
    START_DIFFICULTY: Hash[384] = parseHexStr("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA").toHash(384)
    #Other difficulty.
    OTHER_DIFFICULTY: Hash[384] = parseHexStr("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA").toHash(384)

#Recreate the VotedDifficulty object for testing purposes.
type VotedDifficultyTest = object
    difficulty: Hash[384]
    holders: seq[uint16]

suite "SpamFilter":
    setup:
        var
            #Holder -> Merit.
            merit: Table[uint16, int]
            #List of Difficulties and their votes.
            difficulties: seq[VotedDifficultyTest] = @[]
            #SpamFilter.
            filter: SpamFilter = newSpamFilterObj(START_DIFFICULTY)

    test "Verify the starting difficulty is correct.":
        check(filter.difficulty == START_DIFFICULTY)

    test "Verify adding 0 votes doesn't change the starting difficulty.":
        filter.update(0, 49, OTHER_DIFFICULTY)
        check(filter.difficulty == START_DIFFICULTY)

    test "Add 1 vote and remove it.":
        filter.update(0, 50, OTHER_DIFFICULTY)
        check(filter.difficulty == OTHER_DIFFICULTY)
        filter.handleBlock(1, 1, 0, 49)
        check(filter.difficulty == START_DIFFICULTY)

    midFuzzTest "Verify.":
        #Create a random amount of holders.
        for h in 0 ..< rand(50) + 2:
            merit[uint16(h)] = 0

        #Iterate over 10000 actions.
        for a in 0 ..< 10000:
            #Update a holder's vote.
            #Try a maximum of three times to find a holder with at least 50 Merit.
            for i in 0 ..< 3:
                var
                    holder: uint16 = uint16(rand(merit.len - 1))
                    difficulty: Hash[384]
                if merit[uint16(holder)] < 50:
                    continue

                #Remove the holder from the existing difficulty.
                var d: int = 0
                while d < difficulties.len:
                    for h in 0 ..< difficulties[d].holders.len:
                        if difficulties[d].holders[h] == holder:
                            difficulties[d].holders.del(h)
                            break
                    if difficulties[d].holders.len == 0:
                        difficulties.del(d)
                        continue
                    inc(d)

                #Select an existing difficulty.
                if (difficulties.len != 0) and (rand(2) == 0):
                    var d: int = rand(high(difficulties))
                    difficulty = difficulties[d].difficulty

                    #Add this holder to the difficulty.
                    difficulties[d].holders.add(holder)
                    difficulties[d].holders = difficulties[d].holders.deduplicate()

                #Select a new difficulty.
                else:
                    var found: bool = true
                    while found:
                        for b in 0 ..< 48:
                            difficulty.data[b] = uint8(rand(255))

                        #Break if no existing difficulty is the same.
                        found = false
                        for diff in difficulties:
                            if difficulty == diff.difficulty:
                                found = true
                                break

                    #Add the difficulty to difficulties.
                    difficulties.add(VotedDifficultyTest(
                        difficulty: difficulty,
                        holders: @[uint16(holder)]
                    ))

                #Update the difficulty.
                filter.update(holder, merit[uint16(holder)], difficulty)
                break

            #Increment a holder's Merit.
            if a < 5000:
                var incd: uint16 = uint16(rand(merit.len - 1))
                merit[incd] += 1

                filter.handleBlock(incd, merit[incd])
            #Increment and decrement holders' Merit.
            else:
                var
                    incd: uint16 = uint16(rand(merit.len - 1))
                    decd: uint16 = uint16(rand(merit.len - 1))
                while (decd == incd) or (merit[decd] == 0):
                    decd = uint16(rand(merit.len - 1))
                merit[incd] += 1
                merit[decd] -= 1

                filter.handleBlock(incd, merit[incd], decd, merit[decd])

            #Handle no votes.
            if difficulties.len == 0:
                check(filter.difficulty == START_DIFFICULTY)
                continue

            #Sort difficulties.
            difficulties.sort(
                proc (
                    x: VotedDifficultyTest,
                    y: VotedDifficultyTest
                ): int =
                    if x.difficulty > y.difficulty:
                        return 1
                    elif x.difficulty == y.difficulty:
                        check(false)
                    else:
                        return -1
            )

            #Turn weighted difficulties into a seq.
            var unweighted: seq[Hash[384]] = @[]
            for d in 0 ..< difficulties.len:
                var sum: int = 0
                for h in difficulties[d].holders:
                    sum += merit[h] div 50

                for _ in 0 ..< sum:
                    unweighted.add(difficulties[d].difficulty)

            #Verify the median.
            check(filter.difficulty == unweighted[unweighted.len div 2])
