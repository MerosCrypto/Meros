import ../lib/BN
import ../lib/Hex
import ../lib/Base58

import ../lib/time

import ../lib/SHA512
import ../lib/Lyra2

type Block* = ref object of RootObj
    nonce*: BN
    time*: BN
    miner*: string
    proof*: string
    hash*: string
    lyra*: string

proc createBlock*(nonce: BN, time: BN, miner: string, proof: string): Block =
    Base58.verify(miner)
    Hex.verify(proof)

    result = Block(
        nonce: nonce,
        time: time,
        miner: miner,
        proof: proof
    )

    result.hash = SHA512(Hex.convert(nonce)).substr(0, 31) &
        SHA512(Hex.convert(time)).substr(32, 63) &
        SHA512(Hex.convert(Base58.revert(miner))).substr(64, 127)
    result.lyra = Lyra2(result.hash, result.proof)

proc createBlock*(nonce: BN, miner: string, proof: string): Block =
    result = createBlock(nonce, getTime(), miner, proof)

proc verifyBlock*(newBlock: Block) =
    var createdBlock: Block = createBlock(newBlock.nonce, newBlock.time, newBlock.miner, newBlock.proof)
    if createdBlock.hash != newBlock.hash:
        raise newException(Exception, "Invalid hash")

    if createdBlock.lyra != newBlock.lyra:
        raise newException(Exception, "Invalid lyra")
