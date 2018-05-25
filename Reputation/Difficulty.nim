import ../lib/Hex
import ../lib/BN

import ./Block as BlockFile

import lists, strutils

import os

type Difficulty* = ref object of RootObj
    start*: BN
    endTime*: BN
    difficulty*: string

proc `<`(x: string, y: string): bool =
    if x.len < y.len:
        result = true
        return
    elif y.len < x.len:
        result = false
        return

    for i in 0 ..< x.len:
        if ((int) x[i]) < ((int) y[i]):
            result = true
            return
        elif ((int) x[i]) > ((int) y[i]):
            result = false
            return

    result = false

proc verifyDifficulty*(diff: Difficulty, newBlock: Block) =
    if diff.endTime < newBlock.time:
        raise newException(Exception, "Wrong Difficulty")

    if newBlock.lyra.substr(0, 7) < diff.difficulty:
        echo "Hash is too low:  " & newBlock.lyra.substr(0, 7)
        echo "Must be at least: " & diff.difficulty
        raise newException(Exception, "The hash is too low")

proc calculateNextDifficulty*(blocks: DoublyLinkedList[Block], difficulties: DoublyLinkedList[Difficulty], periodInSeconds: int = (60*60), blocksPerPeriod: int = 6): Difficulty =
    sleep(3000)
    echo "Readjusting difficulty"
    sleep(3000)
    var
        start: BN = difficulties.tail.value.start
        endTime: BN = difficulties.tail.value.endTime
        lastDifficulty: string = difficulties.tail.value.difficulty
        blockCount: uint32 = (uint32) 0
        rate: float32
        strRate: string
        difficulty: string

    for i in items(blocks):
        if i.time < start or i.time > endTime:
            continue
        inc(blockCount)
    echo "Mined " & $blockCount & " blocks in the last minute."

    rate = ((float32) 60) / (float32) blockCount #Difficulty adjustment time in seconds
    if rate == Inf:
        rate = ((float32) 60) / (float32) 1
    rate = rate / ((float32) 5) #Target block time in seconds
    echo "New rate: " & $rate
    rate = (((float32) 1) / rate) * (float32) 1000
    strRate = $(Hex.revert(lastDifficulty) * newBN(($rate).split(".")[0]))
    strRate.insert(".", strRate.len-3)
    rate = parseFloat(strRate)

    difficulty = Hex.convert(newBN(($rate).split(".")[0]))
    if difficulty < difficulties.head.value.difficulty:
        difficulty = difficulties.head.value.difficulty

    result = Difficulty(
        start: endTime,
        endTime: endTime + newBN("60"),
        difficulty: difficulty
    )
