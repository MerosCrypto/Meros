import ../lib/Hex

import ./Block as BlockFile

import lists

type Difficulty* = ref object of RootObj
    start*: uint32
    endTime*: uint32
    difficulty*: string

proc verifyDifficulty*(diff: Difficulty, newBlock: Block) =
    if diff.endTime < newBlock.time:
        raise newException(Exception, "Wrong Difficulty")

    if Hex.revert(diff.difficulty) > Hex.revert(newBlock.hash):
        raise newException(Exception, "The hash is too low")

proc calculateNextDifficulty*(blocks: DoublyLinkedList[Block], difficulties: DoublyLinkedList[Difficulty]): Difficulty =
    var
        start: uint32 = difficulties.tail.value.start
        endTime: uint32 = difficulties.tail.value.endTime
        lastDifficulty: string = difficulties.tail.value.difficulty
        blockCount: uint32 = 0
        rate: uint32

    for i in items(blocks):
        if i.time < start or i.time > endTime:
            continue
        inc(blockCount)

    rate = ((uint32) 24*60*60) div blockCount
    rate = ((uint32) 5*60) div rate
    result = Difficulty(
        start: endTime,
        endTime: endTime + (5*60),
        difficulty: Hex.convert(Hex.revert(lastDifficulty)*rate)
    )
