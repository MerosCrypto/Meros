#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Merit lib.
import ../../../src/Database/Merit/Merit

#Compare Consensus lib.
import ../ConsensusTests/CompareConsensus

#Tables standard lib.
import tables

#Compare two BlockHeaders to make sure they have the same value.
proc compare*(
    bh1: BlockHeader,
    bh2: BlockHeader
) =
    assert(bh1.version == bh2.version)
    assert(bh1.last == bh2.last)
    assert(bh1.contents == bh2.contents)
    assert(bh1.verifiers == bh2.verifiers)
    assert(bh1.newMiner == bh2.newMiner)
    if bh1.newMiner:
        assert(bh1.minerKey == bh2.minerKey)
    else:
        assert(bh1.minerNick == bh2.minerNick)
    assert(bh1.time == bh2.time)
    assert(bh1.proof == bh2.proof)
    assert(bh1.signature == bh2.signature)
    assert(bh1.hash == bh2.hash)

#Compare two BlockBodies to make sure they have the same value.
proc compare*(
    bb1: BlockBody,
    bb2: BlockBody
) =
    assert(bb1.transactions.len == bb2.transactions.len)
    for t in 0 ..< bb1.transactions.len:
        assert(bb1.transactions[t] == bb2.transactions[t])

    assert(bb1.elements.len == bb2.elements.len)
    for e in 0 ..< bb1.elements.len:
        compare(bb1.elements[e], bb2.elements[e])

    assert(bb1.aggregate == bb2.aggregate)

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
    assert(d1.endHeight == d2.endHeight)
    assert(d1.difficulty == d2.difficulty)

#Compare two Blockchains to make sure they have the same value.
proc compare*(
    bc1: Blockchain,
    bc2: Blockchain
) =
    assert(bc1.blockTime == bc2.blockTime)
    compare(bc1.startDifficulty, bc2.startDifficulty)

    assert(bc1.height == bc2.height)
    for b in 0 ..< bc1.height:
        compare(bc1[b], bc2[b])
    compare(bc1.difficulty, bc2.difficulty)

    assert(bc1.miners.len == bc2.miners.len)
    for key in bc1.miners.keys():
        assert(bc1.miners[key] == bc2.miners[key])

#Compare two States to make sure they have the same value.
proc compare*(
    s1: State,
    s2: State
) =
    assert(s1.deadBlocks == s2.deadBlocks)
    assert(s1.live == s2.live)
    assert(s1.processedBlocks == s2.processedBlocks)

    assert(s1.holders.len == s2.holders.len)
    for h in 0 ..< s1.holders.len:
        assert(s1.holders[h] == s2.holders[h])
        assert(uint16(h) == s1.reverseLookup(s1.holders[h]))
        assert(s1[uint16(h)] == s2[uint16(h)])

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
