#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Merit lib.
import ../../../src/Database/Merit/Merit

#StInt lib.
import StInt

#Tables standard lib.
import tables

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

#Compare two MeritHolderRecords to make sure they have the same value.
proc compare*(
    mhr1: MeritHolderRecord,
    mhr2: MeritHolderRecord
) =
    assert(mhr1.key == mhr2.key)
    assert(mhr1.nonce == mhr2.nonce)
    assert(mhr1.merkle == mhr2.merkle)

#Compare two sets of MeritHolderRecords to make sure they have the same value.
proc compare*(
    mhr1: seq[MeritHolderRecord],
    mhr2: seq[MeritHolderRecord]
) =
    assert(mhr1.len == mhr2.len)
    for i in 0 ..< mhr1.len:
        compare(mhr1[i], mhr2[i])

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
    s1: var State,
    s2: var State
) =
    assert(s1.deadBlocks == s2.deadBlocks)
    assert(s1.live == s2.live)
    assert(s1.processedBlocks == s2.processedBlocks)

    var
        s1Holders: seq[string] = @[]
        s2Holders: seq[string] = @[]
    for k in s1.holders():
        if s1[k] == 0:
            continue
        s1Holders.add(k)
    for k in s2.holders():
        if s2[k] == 0:
            continue
        s2Holders.add(k)

    assert(s1Holders.len == s2Holders.len)
    for k in s1Holders:
        assert(s2Holders.contains(k))
        assert(s1[k] == s2[k])

#Compare two Epochs to make sure they have the same value.
proc compare*(
    e1Arg: Epochs,
    e2Arg: Epochs
) =
    var
        #Extract the arguments.
        e1: Epochs = e1Arg
        e2: Epochs = e2Arg
        #Popped Epochs.
        p1: Epoch
        p2: Epoch

    for _ in 0 ..< 6:
        #Check the Epochs' records.
        assert(e1.records.len == e2.records.len)
        for r1 in 0 ..< e1.records.len:
            assert(e1.records[r1].len == e2.records[r1].len)
            for r2 in 0 ..< e1.records[r1].len:
                compare(e1.records[r1][r2], e2.records[r1][r2])

        #Shift on an Epoch.
        p1 = e1.shift(nil, @[], @[])
        p2 = e2.shift(nil, @[], @[])

        #Make sure the Epochs are equivalent.
        assert(p1.hashes.len == p2.hashes.len)
        for h in p1.hashes.keys():
            assert(p1.hashes[h].len == p2.hashes[h].len)
            for k in 0 ..< p1.hashes[h].len:
                assert(p1.hashes[h][k] == p2.hashes[h][k])

        assert(p1.records.len == p2.records.len)
        compare(p1.records, p2.records)
