import ../lib/UInt
import ../lib/Hex
import ../lib/Base58

import ../lib/time

import ../lib/SHA512

type Block* = ref object of RootObj
    nonce*: UInt
    time*: UInt
    miner*: string
    proof*: string
    hash*: string

proc createBlock*(nonce: UInt, time: UInt, miner: string, proof: string): Block =
    Base58.verify(miner)
    Hex.verify(proof)
    echo "Verified Base58 and Hex"

    result = Block(
        nonce: nonce,
        time: time,
        miner: miner,
        proof: proof
    )
    echo "Created Block Result"

    result.hash = SHA512(Hex.convert(nonce)).substr(0, 31)
    echo "Calculated Nonce Hash"
    var hexTime: string = Hex.convert(time, true)
    echo "Converted time to hex"
    result.hash = result.hash & SHA512(hexTime).substr(64, 95)
    echo "Calculated Time Hash"
    result.hash = result.hash & SHA512(Hex.convert(Base58.revert(miner))).substr(32, 63)
    echo "Calculated Miner Hash"
    result.hash = result.hash & SHA512(proof).substr(96, 127)
    echo "Calculated Hashes"

proc createBlock*(nonce: UInt, miner: string, proof: string): Block =
    result = createBlock(nonce, getTime(), miner, proof)

proc verifyBlock*(newBlock: Block) =
    var createdBlock: Block = createBlock(newBlock.nonce, newBlock.time, newBlock.miner, newBlock.proof)
    if createdBlock.hash != newBlock.hash:
        raise newException(Exception, "Invalid hash")
