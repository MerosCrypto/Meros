import deques

#Fuzzing lib.
import ../../Fuzzed

#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Element libs.
import ../../../src/Database/Consensus/Elements/Elements

#Merit libs.
import ../../../src/Database/Merit/Merit

#Compare Consensus lib.
import ../Consensus/CompareConsensus

#Tables standard lib.
import tables

#Compare two BlockHeaders to make sure they have the same value.
proc compare*(
  bh1: BlockHeader,
  bh2: BlockHeader
) =
  check(bh1.version == bh2.version)
  check(bh1.last == bh2.last)
  check(bh1.contents == bh2.contents)

  check(bh1.significant == bh2.significant)
  check(bh1.sketchSalt == bh2.sketchSalt)
  check(bh1.sketchCheck == bh2.sketchCheck)

  check(bh1.newMiner == bh2.newMiner)
  if bh1.newMiner:
    check(bh1.minerKey == bh2.minerKey)
  else:
    check(bh1.minerNick == bh2.minerNick)

  check(bh1.time == bh2.time)
  check(bh1.proof == bh2.proof)
  check(bh1.signature == bh2.signature)

  check(bh1.interimHash == bh2.interimHash)
  check(bh1.hash == bh2.hash)

#Compare two BlockBodies to make sure they have the same value.
proc compare*(
  bb1: BlockBody,
  bb2: BlockBody
) =
  check(bb1.packetsContents == bb2.packetsContents)

  check(bb1.packets.len == bb2.packets.len)
  for p in 0 ..< bb1.packets.len:
    compare(bb1.packets[p], bb2.packets[p])

  check(bb1.elements.len == bb2.elements.len)
  for e in 0 ..< bb1.elements.len:
    compare(bb1.elements[e], bb2.elements[e])

  check(bb1.aggregate == bb2.aggregate)

#Compare two Blocks to make sure they have the same value.
proc compare*(
  b1: Block,
  b2: Block
) =
  compare(b1.header, b2.header)
  compare(b1.body, b2.body)

#Compare two Blockchains to make sure they have the same value.
proc compare*(
  bc1: Blockchain,
  bc2: Blockchain
) =
  check(bc1.genesis == bc2.genesis)
  check(bc1.blockTime == bc2.blockTime)

  check(bc1.height == bc2.height)
  var last: Hash[256] = bc1.genesis
  for b in 0 ..< bc1.height:
    check(bc1[b].header.last == last)
    compare(bc1[b], bc2[b])
    last = bc1[b].header.hash
  check(bc1.tail.header.hash == last)
  check(bc2.tail.header.hash == last)
  check(bc1.difficulties == bc2.difficulties)
  check(bc1.chainWork == bc2.chainWork)

  check(bc1.rx.cacheKey == bc2.rx.cacheKey)

  check(bc1.miners.len == bc2.miners.len)
  for key in bc1.miners.keys():
    check(bc1.miners[key] == bc2.miners[key])

#Compare two States to make sure they have the same value.
proc compare*(
  s1: State,
  s2: State
) =
  check(s1.deadBlocks == s2.deadBlocks)
  check(s1.unlocked == s2.unlocked)
  check(s1.processedBlocks == s2.processedBlocks)

  check(s1.holders.len == s2.holders.len)
  for h in 0 ..< s1.holders.len:
    check(s1.holders[h] == s2.holders[h])
    check(uint16(h) == s1.reverseLookup(s1.holders[h]))
    check(s1[uint16(h), s1.processedBlocks] == s2[uint16(h), s1.processedBlocks])

  check(s1.pendingRemovals == s2.pendingRemovals)

#Compare two Epochs to make sure they have the same values.
proc compare*(
  e1Arg: Epochs,
  e2Arg: Epochs
) =
  check(e1Arg.len == 5)
  check(e2Arg.len == 5)

  for e in 0 ..< 5:
    check(e1Arg[e].len == e2Arg[e].len)
    for h in e1Arg[e].keys():
      check(e1Arg[e][h].len == e2Arg[e][h].len)
      for k in 0 ..< e1Arg[e][h].len:
        check(e1Arg[e][h][k] == e2Arg[e][h][k])
