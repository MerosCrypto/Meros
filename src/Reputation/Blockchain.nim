import ../lib/BN
import ../lib/time

import Block as BlockFile
import Difficulty as DifficultyFile

import lists

type Blockchain* = ref object of RootObj
    creation: BN
    genesis: string
    height: BN
    blocks: DoublyLinkedList[Block]
    difficulties: DoublyLinkedList[Difficulty]

proc createBlockchain*(genesis: string): Blockchain =
    result = Blockchain(
        creation: getTime(),
        genesis: genesis,
        height: newBN("0"),
        blocks: initDoublyLinkedList[Block](),
        difficulties: initDoublyLinkedList[Difficulty]()
    );

    result.difficulties.append(Difficulty(
        start: result.creation,
        endTime: result.creation + newBN("60"),
        difficulty: "1111111111111111111111111111111111111111111111111111111111111111"
    ))
    result.blocks.append(createBlock(newBN("0"), "1", "0"))

proc testBlock*(blockchain: Blockchain, newBlock: Block) =
    if blockchain.height + BNNums.ONE != newBlock.getNonce():
        raise newException(Exception, "Invalid nonce")

    verifyBlock(newBlock)

    while blockchain.difficulties.tail.value.endTime < newBlock.getTime():
        blockchain.difficulties.append(calculateNextDifficulty(blockchain.blocks, blockchain.difficulties, (60), 6))

    blockchain.difficulties.tail.value.verifyDifficulty(newBlock)

proc addBlock*(blockchain: Blockchain, newBlock: Block) =
    try:
        blockchain.testBlock(newBlock):
    except:
        return

    inc(blockchain.height)
    blockchain.blocks.append(newBlock)

proc getCreation*(blockchain: Blockchain): BN =
    result = blockchain.creation
proc getGenesis*(blockchain: Blockchain): string =
    result = blockchain.genesis
proc getHeight*(blockchain: Blockchain): BN =
    result = blockchain.height
proc getBlocks*(blockchain: Blockchain): DoublyLinkedList[Block] =
    result = blockchain.blocks
proc getDifficulties*(blockchain: Blockchain): DoublyLinkedList[Difficulty] =
    result = blockchain.difficulties
