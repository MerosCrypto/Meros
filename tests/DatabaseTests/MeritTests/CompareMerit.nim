#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Merit lib.
import ../../../src/Database/Merit/Merit

#StInt lib.
import StInt

#Compare two BlockHeaders to make sure they have the same value.
proc compare*(
    bh1: BlockHeader,
    bh2: BlockHeader
) =
    assert(bh1.hash == bh2.hash)
    assert(bh1.nonce == bh2.nonce)
    assert(bh1.last == bh2.last)
    assert(bh1.aggregate == bh2.aggregate)
    assert(bh1.miners == bh2.miners)
    assert(bh1.time == bh2.time)
    assert(bh1.proof == bh2.proof)

#Compare two sets of MeritHolderRecords to make sure they have the same value.
proc compare*(
    mhr1: seq[MeritHolderRecord],
    mhr2: seq[MeritHolderRecord]
) =
    assert(mhr1.len == mhr2.len)
    for i in 0 ..< mhr1.len:
        assert(mhr1[i].key == mhr2[i].key)
        assert(mhr1[i].nonce == mhr2[i].nonce)
        assert(mhr1[i].merkle == mhr2[i].merkle)

#Compare two Miners to make sure they have the same value.
proc compare*(
    m1: Miners,
    m2: Miners
) =
    assert(m1.merkle.hash == m2.merkle.hash)
    assert(m1.miners.len == m2.miners.len)
    for i in 0 ..< m1.miners.len:
        assert(m1.miners[i].miner == m2.miners[i].miner)
        assert(m1.miners[i].amount == m2.miners[i].amount)

#Compare two BlockBodies to make sure they have the same value.
proc compare*(
    bb1: BlockBody,
    bb2: BlockBody
) =
    compare(bb1.records, bb2.records)
    compare(bb1.miners, bb2.miners)

#Compare two Blocks to make sure they have the same value.
proc compare*(
    b1: Block,
    b2: Block
) =
    compare(b1.header, b2.header)
    compare(b1.body, b2.body)

#Compare two Difficulties to make sure they have the same value.
proc compare*(
    d1: Difficulty,
    d2: Difficulty
) =
    assert(d1.start == d2.start)
    assert(d1.endBlock == d2.endBlock)
    assert(d1.difficulty == d2.difficulty)

#Compare two Blockchains to make sure they have the same value.
proc compare*(
    bc1: Blockchain,
    bc2: Blockchain
) =
    assert(bc1.blockTime == bc2.blockTime)
    compare(bc1.startDifficulty, bc2.startDifficulty)

    assert(bc1.height == bc2.height)
    for i in 0 ..< bc1.height:
        compare(bc1.headers[i], bc2.headers[i])
        compare(bc1[i], bc2[i])

    compare(bc1.difficulty, bc2.difficulty)

#Compare two States to make sure they have the same value.
proc compare*(
    bb1: State,
    bb2: State
) =
    discard

#Compare two Epochs to make sure they have the same value.
proc compare*(
    bb1: Epoch,
    bb2: Epoch
) =
    discard
