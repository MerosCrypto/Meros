#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Element libs.
import ../../../src/Database/Consensus/Elements/Elements

#Merit libs.
import ../../../src/Database/Merit/Merit

#Compare Consensus lib.
import ../ConsensusTests/CompareConsensus

#Merit Testing Functions.
import TestMerit

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

    assert(bh1.significant == bh2.significant)
    assert(bh1.sketchSalt == bh2.sketchSalt)
    assert(bh1.sketchCheck == bh2.sketchCheck)

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
    assert(bb1.packets.len == bb2.packets.len)
    for p in 0 ..< bb1.packets.len:
        compare(bb1.packets[p], bb2.packets[p])

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
    assert(s1.unlocked == s2.unlocked)
    assert(s1.processedBlocks == s2.processedBlocks)

    assert(s1.holders.len == s2.holders.len)
    for h in 0 ..< s1.holders.len:
        assert(s1.holders[h] == s2.holders[h])
        assert(uint16(h) == s1.reverseLookup(s1.holders[h]))
        assert(s1[uint16(h)] == s2[uint16(h)])

#Compare two Epochs to make sure they have the same values.
proc compare*(
    e1Arg: Epochs,
    e2Arg: Epochs
) =
    assert(e1Arg.len == 5)
    assert(e2Arg.len == 5)

    for e in 0 ..< 5:
        assert(e1Arg[e].len == e2Arg[e].len)
        for h in e1Arg[e].keys():
            assert(e1Arg[e][h].len == e2Arg[e][h].len)
            for k in 0 ..< e1Arg[e][h].len:
                assert(e1Arg[e][h][k] == e2Arg[e][h][k])
