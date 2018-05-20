import ../lib/time
import ../lib/Hex
import ../lib/Base58
import ../lib/SHA512

type Block* = ref object of RootObj
    nonce*: uint32
    time*: uint32
    miner*: string
    proof*: string
    hash*: string

proc createBlock*(nonce: uint32, time: uint32, miner: string, proof: string): Block =
    Base58.verify(miner)
    Hex.verify(proof)

    result = Block(
        nonce: nonce,
        time: time,
        miner: miner,
        proof: proof
    )

    result.hash =
        SHA512(Hex.convert(nonce)).substr(0, 31) &
        SHA512(Hex.convert(time)).substr(64, 95) &
        SHA512(Hex.convert(Base58.revert(miner))).substr(32, 63) &
        SHA512(proof).substr(96, 127)

proc createBlock*(nonce: uint32, miner: string, proof: string): Block =
    result = createBlock(nonce, getTime(), miner, proof)

proc verifyBlock*(newBlock: Block) =
    var createdBlock: Block = createBlock(newBlock.nonce, newBlock.time, newBlock.miner, newBlock.proof)
    if createdBlock.hash != newBlock.hash:
        raise newException(Exception, "Invalid hash")
