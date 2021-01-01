import random

import ../../../src/lib/[Util, Hash]
import ../../../src/Wallet/MinerWallet

import ../../../src/Database/Consensus/Elements/Elements
import ../../../src/Database/Merit/Block

import ../../Fuzzed
import ../TestDatabase
export TestDatabase

var rx: RandomX = newRandomX()
proc getRandomX*(): RandomX =
  {.gcsafe.}:
    rx

proc newValidVerificationPacket*(
  holders: seq[BLSPublicKey],
  exclude: set[uint16] = {},
  hash: Hash[256] = newRandomHash()
): VerificationPacket =
  result = newVerificationPacketObj(hash)
  for h in 0 ..< holders.len:
    if exclude.contains(uint16(h)):
      continue

    if rand(1) == 0:
      result.holders.add(uint16(h))

  #Make sure there's at least one holder.
  while result.holders.len == 0:
    var h: uint16 = uint16(rand(high(holders)))
    if exclude.contains(h):
      continue
    result.holders.add(h)

#Create a Block, with every setting optional.
var lastTime {.threadvar.}: uint32
proc newBlankBlock*(
  rx: RandomX,
  version: uint32 = 0,
  last: Hash[256] = Hash[256](),
  sketchSalt: string = newString(4),
  miner: MinerWallet = newMinerWallet(),
  packets: seq[VerificationPacket] = @[],
  elements: seq[BlockElement] = @[],
  removals: set[uint16] = {},
  aggregate: BLSSignature = newBLSSignature(),
  time: uint32 = 0,
  proof: uint32 = 0
): Block =
  var actualTime: uint32 = time
  if actualTime == 0:
    actualTime = max(getTime(), lastTime + 1)
    lastTime = actualTime

  var contents: tuple[packets: Hash[256], contents: Hash[256]] = newContents(packets, elements)
  result = newBlockObj(
    newBlockHeaderObj(
      version,
      last,
      contents.contents,
      uint32(packets.len),
      sketchSalt,
      newSketchCheck(sketchSalt, packets),
      miner.publicKey,
      actualTime,
      proof,
      newBLSSignature()
    ),
    newBlockBodyObj(
      contents.packets,
      packets,
      elements,
      aggregate,
      removals
    )
  )
  rx.hash(miner, result.header, proof)

#Create a Block with a nickname.
proc newBlankBlock*(
  rx: RandomX,
  version: uint32 = 0,
  last: Hash[256] = Hash[256](),
  sketchSalt: string = newString(4),
  nick: uint16,
  miner: MinerWallet = newMinerWallet(),
  packets: seq[VerificationPacket] = @[],
  elements: seq[BlockElement] = @[],
  removals: set[uint16] = {},
  aggregate: BLSSignature = newBLSSignature(),
  time: uint32 = 0,
  proof: uint32 = 0
): Block =
  var actualTime: uint32 = time
  if actualTime == 0:
    actualTime = max(getTime(), lastTime + 1)
    lastTime = actualTime

  var contents: tuple[packets: Hash[256], contents: Hash[256]] = newContents(packets, elements)
  result = newBlockObj(
    newBlockHeaderObj(
      version,
      last,
      contents.contents,
      uint32(packets.len),
      sketchSalt,
      newSketchCheck(sketchSalt, packets),
      nick,
      actualTime,
      proof,
      newBLSSignature()
    ),
    newBlockBodyObj(
      contents.packets,
      packets,
      elements,
      aggregate,
      removals
    )
  )
  rx.hash(miner, result.header, proof)
