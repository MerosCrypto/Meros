import ../lib/time

import ./Block as BlockFile
import ./Difficulty as DifficultyFile

import lists

type Blockchain* = ref object of RootObj
    creation: uint32
    genesis: string
    height: uint32
    blocks: DoublyLinkedList[Block]
    difficulties: DoublyLinkedList[Difficulty]

proc createBlockchain*(genesis: string): Blockchain =
    result = Blockchain(
        creation: getTime(),
        genesis: genesis,
        height: 0,
        blocks: initDoublyLinkedList[Block](),
        difficulties: initDoublyLinkedList[Difficulty]()
    );

    result.difficulties.append(Difficulty(
        start: result.creation,
        endTime: result.creation + (60),
        difficulty: "44444444"
    ))
    result.blocks.append(createBlock(0, "1", "0"))

proc addBlock*(blockchain: Blockchain, newBlock: Block) =
    if blockchain.height + 1 != newBlock.nonce:
        echo $blockchain.height
        echo $(newBlock.nonce + 1)
        raise newException(Exception, "Invalid nonce")

    verifyBlock(newBlock)

    while blockchain.difficulties.tail.value.endTime < newBlock.time:
        blockchain.difficulties.append(calculateNextDifficulty(blockchain.blocks, blockchain.difficulties))

    blockchain.difficulties.tail.value.verifyDifficulty(newBlock)

    inc(blockchain.height)
    blockchain.blocks.append(newBlock)
