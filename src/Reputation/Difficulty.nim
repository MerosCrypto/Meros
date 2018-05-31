import ../lib/Hex
import ../lib/BN

import Block as BlockFile

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
    if diff.endTime < newBlock.getTime():
        raise newException(Exception, "Wrong Difficulty")

    if newBlock.getLyra() < diff.difficulty:
        echo "Hash is too low:  " & newBlock.getLyra()
        echo "Must be at least: " & diff.difficulty
        raise newException(Exception, "The hash is too low")

proc calculateNextDifficulty*(blocks: DoublyLinkedList[Block], difficulties: DoublyLinkedList[Difficulty], periodInSeconds: int, blocksPerPeriod: int): Difficulty =
    sleep(3000)
    echo "Readjusting difficulty"
    sleep(3000)
    var
        start: BN = difficulties.tail.value.start
        endTime: BN = difficulties.tail.value.endTime
        lastDifficulty: string = difficulties.tail.value.difficulty
        blockCount: int = 0
        rate: float64
        difficulty: string

    for i in items(blocks):
        if i.getTime() < start or i.getTime() > endTime:
            continue
        inc(blockCount)
    echo "Mined " & $blockCount & " blocks in the last period."

    if blocksPerPeriod < blockCount:
        rate = blockCount / blocksPerPeriod
    elif blocksPerPeriod == blockCount:
        result = Difficulty(
            start: endTime,
            endTime: endTime + newBN($periodInSeconds),
            difficulty: lastDifficulty
        )
        return
    elif blocksPerPeriod > blockCount:
        rate = blocksPerPeriod / blockCount

    if blockCount == 0:
        rate = 0

    var bnRate: BN = newBN(($rate).split(".")[0])
    if blockCount < blocksPerPeriod:
        difficulty = Hex.convert((Hex.revert(lastDifficulty) / bnRate))
    elif blockCount > blocksPerPeriod:
        difficulty = Hex.convert(Hex.revert(lastDifficulty) * bnRate)

    if Hex.revert(difficulty) < Hex.revert(difficulties.head.value.difficulty):
        difficulty = difficulties.head.value.difficulty

    echo "The last difficulty was: " & $Hex.revert(lastDifficulty)
    echo "The new difficulty is:   " & $Hex.revert(difficulty)

    result = Difficulty(
        start: endTime,
        endTime: endTime + newBN($periodInSeconds),
        difficulty: difficulty
    )
