import ../lib/Hex
import ../lib/UInt

import ./Block as BlockFile

import lists

import os

type Difficulty* = ref object of RootObj
    start*: uint32
    endTime*: uint32
    difficulty*: string

proc verifyDifficulty*(diff: Difficulty, newBlock: Block) =
    if diff.endTime < newBlock.time:
        raise newException(Exception, "Wrong Difficulty")

    if Hex.revert(diff.difficulty) > Hex.revert(newBlock.hash.substr(0, 7)):
        echo "Hash is too low:  " & $Hex.revert(newBlock.hash.substr(96, 103))
        echo "Must be at least: " & $Hex.revert(diff.difficulty)
        raise newException(Exception, "The hash is too low")

proc calculateNextDifficulty*(blocks: DoublyLinkedList[Block], difficulties: DoublyLinkedList[Difficulty]): Difficulty =
    sleep(3000)
    echo "Readjusting difficulty"
    sleep(3000)
    var
        start: uint32 = difficulties.tail.value.start
        endTime: uint32 = difficulties.tail.value.endTime
        lastDifficulty: string = difficulties.tail.value.difficulty
        blockCount: uint32 = 0
        rate: float32

    for i in items(blocks):
        if i.time < start or i.time > endTime:
            continue
        inc(blockCount)
    echo "Mined " & $blockCount & " blocks in the last minute."

    rate = ((float32) 60) / (float32) blockCount #Difficulty adjustment time in seconds
    rate = rate / ((float32) 5) #Target block time in seconds
    echo "New rate: " & $rate
    result = Difficulty(
        start: endTime,
        endTime: endTime + (60),
        difficulty: Hex.convert((Hex.revert(lastDifficulty).float32 * ((float32) 1 / rate)).uint32)
    )
