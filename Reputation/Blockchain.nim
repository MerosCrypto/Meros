import ../lib/UInt
import ../lib/time

import ./Block as BlockFile
import ./Difficulty as DifficultyFile

import lists

type Blockchain* = ref object of RootObj
    creation: UInt
    genesis: string
    height: UInt
    blocks: DoublyLinkedList[Block]
    difficulties: DoublyLinkedList[Difficulty]

proc createBlockchain*(genesis: string): Blockchain =
    result = Blockchain(
        creation: getTime(),
        genesis: genesis,
        height: newUInt("0"),
        blocks: initDoublyLinkedList[Block](),
        difficulties: initDoublyLinkedList[Difficulty]()
    );
    echo "Created result"

    result.difficulties.append(Difficulty(
        start: result.creation,
        endTime: result.creation + newUInt("60"),
        difficulty: "44444444"
    ))
    echo "Created Difficulty"
    result.blocks.append(createBlock(newUInt("0"), "1", "0"))
    echo "Appended Genesis block"

proc addBlock*(blockchain: Blockchain, newBlock: Block) =
    if blockchain.height + newUInt("1") != newBlock.nonce:
        raise newException(Exception, "Invalid nonce")

    verifyBlock(newBlock)

    while blockchain.difficulties.tail.value.endTime < newBlock.time:
        blockchain.difficulties.append(calculateNextDifficulty(blockchain.blocks, blockchain.difficulties))

    blockchain.difficulties.tail.value.verifyDifficulty(newBlock)

    inc(blockchain.height)
    blockchain.blocks.append(newBlock)
