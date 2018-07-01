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

proc newBlockchain*(genesis: string): Blockchain =
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
    result.blocks.append(newBlock(newBN("0"), result.creation, "Emb000000000000000000000000000000000000000000000000000000000000", "0"))

proc testBlock*(blockchain: Blockchain, newBlock: Block): bool =
    result = true

    if blockchain.height + BNNums.ONE != newBlock.getNonce():
        result = false
        return

    if blockchain.blocks.tail.value.getTime() >= newBlock.getTime():
        result = false
        return

    if not verifyBlock(newBlock):
        result = false
        return

    while blockchain.difficulties.tail.value.endTime < newBlock.getTime():
        blockchain.difficulties.append(calculateNextDifficulty(blockchain.blocks, blockchain.difficulties, (60), 6))

    if not blockchain.difficulties.tail.value.verifyDifficulty(newBlock):
        result = false
        return

proc addBlock*(blockchain: Blockchain, newBlock: Block): bool =
    result = true

    if not blockchain.testBlock(newBlock):
        result = false
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

iterator getBlocks*(blockchain: Blockchain): Block =
    for i in blockchain.blocks.items():
        yield i

proc getDifficulties*(blockchain: Blockchain): DoublyLinkedList[Difficulty] =
    result = blockchain.difficulties
