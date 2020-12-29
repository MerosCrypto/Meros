import deques
import tables

import ../../../src/lib/Hash
import ../../../src/Wallet/MinerWallet

import ../../../src/Database/Consensus/Elements/Elements
import ../../../src/Database/Merit/Merit

import ../../Fuzzed
import ../Consensus/CompareConsensus

proc compare*(
  bh1: BlockHeader,
  bh2: BlockHeader
) =
  check:
    bh1.version == bh2.version
    bh1.last == bh2.last
    bh1.contents == bh2.contents

    bh1.packetsQuantity == bh2.packetsQuantity
    bh1.sketchSalt == bh2.sketchSalt
    bh1.sketchCheck == bh2.sketchCheck

    bh1.newMiner == bh2.newMiner

  if bh1.newMiner:
    check bh1.minerKey == bh2.minerKey
  else:
    check bh1.minerNick == bh2.minerNick

  check:
    bh1.time == bh2.time
    bh1.proof == bh2.proof
    bh1.signature == bh2.signature

    bh1.interimHash == bh2.interimHash
    bh1.hash == bh2.hash

#Compare two BlockBodies to make sure they have the same value.
proc compare*(
  bb1: BlockBody,
  bb2: BlockBody
) =
  check:
    bb1.packetsContents == bb2.packetsContents
    bb1.packets.len == bb2.packets.len
    bb1.elements.len == bb2.elements.len
    bb1.aggregate == bb2.aggregate

  for p in 0 ..< bb1.packets.len:
    compare(bb1.packets[p], bb2.packets[p])
  for e in 0 ..< bb1.elements.len:
    compare(bb1.elements[e], bb2.elements[e])

  check bb1.removals == bb2.removals

proc compare*(
  b1: Block,
  b2: Block
) =
  compare(b1.header, b2.header)
  compare(b1.body, b2.body)

proc compare*(
  bc1: Blockchain,
  bc2: Blockchain
) =
  check bc1.height == bc2.height

  var last: Hash[256] = bc1.genesis
  for b in 0 ..< bc1.height:
    check bc1[b].header.last == last
    compare(bc1[b], bc2[b])
    last = bc1[b].header.hash

  check:
    bc1.genesis == bc2.genesis
    bc1.blockTime == bc2.blockTime

    bc1.tail.header.hash == last
    bc2.tail.header.hash == last

    bc1.difficulties == bc2.difficulties
    bc1.chainWork == bc2.chainWork
    bc1.rx.cacheKey == bc2.rx.cacheKey

    bc1.miners.len == bc2.miners.len

  for key in bc1.miners.keys():
    check bc1.miners[key] == bc2.miners[key]

proc compare*(
  s1: State,
  s2: State
) =
  check:
    s1.oldData == s2.oldData

    s1.deadBlocks == s2.deadBlocks

    s1.total == s2.total
    s1.pending == s2.pending
    s1.counted == s2.counted

    s1.processedBlocks == s2.processedBlocks

    s1.holders.len == s2.holders.len
    s1.merit == s2.merit
    s1.statuses == s2.statuses
    s1.lastParticipation == s2.lastParticipation

    #Sanity check.
    s1.pendingRemovals.len == 6
    s1.pendingRemovals.len == s2.pendingRemovals.len

  for p in 0 ..< s1.pendingRemovals.len:
    check s1.pendingRemovals[p] == s2.pendingRemovals[p]

  for h in 0 ..< s1.holders.len:
    check:
      s1.holders[h] == s2.holders[h]
      uint16(h) == s1.reverseLookup(s1.holders[h])
      uint16(h) == s2.reverseLookup(s2.holders[h])

  check s1.hasMR == s2.hasMR

proc compare*(
  e1Arg: Epochs,
  e2Arg: Epochs
) =
  check:
    e1Arg.len == 5
    e2Arg.len == 5

  for e in 0 ..< 5:
    check e1Arg[e].len == e2Arg[e].len
    for h in e1Arg[e].keys():
      check e1Arg[e][h].len == e2Arg[e][h].len
      for k in 0 ..< e1Arg[e][h].len:
        check e1Arg[e][h][k] == e2Arg[e][h][k]
