import random

import ../../../../../../src/lib/[Util, Hash]
import ../../../../../../src/Wallet/MinerWallet

import ../../../../../../src/Database/Merit/[BlockHeader, Block]

import ../../../../../../src/Database/Filesystem/DB/Serialize/Merit/[
  DBSerializeBlock,
  DBParseBlock
]

import ../../../../../Fuzzed
import ../../../../Consensus/Elements/TestElements
import ../../../../Merit/[TestMerit, CompareMerit]

#Whether or not to create a Block with a new miner.
#Flipped on every test iteration.
var newMiner: bool = true

suite "DBSerializeBlock":
  setup:
    var
      last: Hash[256] = newRandomHash()
      packets: seq[VerificationPacket] = @[]
      elements: seq[BlockElement] = @[]
      removals: set[uint16] = {}
      newBlock: Block
      reloaded: Block

  highFuzzTest "Serialize and parse.":
    for p in 0 ..< rand(300):
      packets.add(newRandomVerificationPacket())
    for _ in 0 ..< rand(300):
      elements.add(newRandomBlockElement())
    for h in 0 .. int(high(uint16)):
      if rand(32) == 0:
        removals.incl(uint16(h))

    if newMiner:
      newBlock = newBlankBlock(
        getRandomX(),
        uint32(rand(4096)),
        last,
        char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
        newMinerWallet(),
        packets,
        elements,
        removals,
        newMinerWallet().sign($rand(4096)),
        uint32(rand(high(int32))),
        uint32(rand(high(int32)))
      )
    else:
      newBlock = newBlankBlock(
        getRandomX(),
        uint32(rand(4096)),
        last,
        char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
        uint16(rand(high(int16))),
        newMinerWallet(),
        packets,
        elements,
        removals,
        newMinerWallet().sign($rand(4096)),
        uint32(rand(high(int32))),
        uint32(rand(high(int32)))
      )

    #No Sketch collision check os performed as this doesn't generate/save any sketch.

    reloaded = newBlock.serialize().parseBlock(newBlock.header.interimHash, newBlock.header.hash)
    compare(newBlock, reloaded)
    check newBlock.serialize() == reloaded.serialize()

    newMiner = not newMiner
