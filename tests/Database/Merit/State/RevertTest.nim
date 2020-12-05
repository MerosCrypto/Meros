import random

import ../../../../src/lib/Util
import ../../../../src/Wallet/MinerWallet

import ../../../../src/Database/Consensus/Elements/Elements
import ../../../../src/Database/Merit/[Difficulty, Block, Blockchain, State]

import ../../../Fuzzed
import ../TestMerit
import ../CompareMerit

suite "Revert":
  setup:
    var
      db: DB = newTestDatabase()
      blockchain: Blockchain = newBlockchain(
        db,
        "STATE_TEST",
        1,
        uint64(1)
      )
      states: seq[State] = @[]

      miners: seq[MinerWallet] = @[]
      #Miners we removed Merit from.
      removed: set[uint16] = {}
      #Selected miner to remove Merit from/for the next Block.
      miner: uint16

      #Miners we're about to remove Merit from.
      toRemove: set[uint16] = {}
      mining: Block

    #Create the initial state.
    states.add(newState(db, 7, blockchain))

    #Iterate over 20 'rounds'.
    for _ in 1 .. 20:
      #Remove Merit from a random amount of Merit Holders every few Blocks.
      if rand(5) == 0:
        for _ in 0 .. min(rand(2), miners.len - removed.card - 1):
          miner = uint16(rand(high(miners)))
          while removed.contains(miner):
            miner = uint16(rand(high(miners)))
          removed.incl(miner)
          toRemove.incl(miner)

      #Decide if this is a nickname or new miner Block.
      if (miners.len == removed.card) or (rand(2) == 0):
        #New miner.
        miner = uint16(miners.len)
        miners.add(newMinerWallet())

        #Create the Block with the new miner.
        mining = newBlankBlock(
          rx = blockchain.rx,
          last = blockchain.tail.header.hash,
          miner = miners[int(miner)],
          removals = toRemove
        )
      else:
        #Grab a random miner.
        miner = uint16(rand(high(miners)))
        while removed.contains(miner):
          miner = uint16(rand(high(miners)))

        #Create the Block with the existing miner.
        mining = newBlankBlock(
          rx = blockchain.rx,
          last = blockchain.tail.header.hash,
          nick = miner,
          miner = miners[int(miner)],
          removals = toRemove
        )

      #Add it to the Blockchain and latest State.
      blockchain.processBlock(mining)
      discard states[^1].processBlock(blockchain)

      #Commit the DB.
      db.commit(blockchain.height)

      #Clear the pending removals.
      toRemove = {}

      #Copy the State.
      states.add(states[^1])

  noFuzzTest "Reversions.":
    var
      copy: State
      reloaded: State
    for s in 2 ..< states.len:
      var revertTo: int = max(rand(s - 1), 1)
      copy = states[s]
      copy.revert(blockchain, states[revertTo].processedBlocks)
      compare(copy, states[revertTo])

      reloaded = newState(db, 7, blockchain)
      compare(states[^1], reloaded)

    #Manually set the RandomX instance to null to make sure it's GC'able.
    blockchain.rx = nil

  midFuzzTest "Chained reversions.":
    var
      copy: State
      reloaded: State
      revertedAtOnce: State

    copy = states[^(rand(3) + 1)]
    copy.revert(blockchain, copy.processedBlocks - (rand(3) + 1))
    copy.revert(blockchain, copy.processedBlocks - (rand(3) + 1))
    copy.revert(blockchain, copy.processedBlocks - (rand(3) + 1))

    revertedAtOnce = states[^1]
    revertedAtOnce.revert(blockchain, copy.processedBlocks)
    compare(copy, revertedAtOnce)

    reloaded = newState(db, 7, blockchain)
    compare(states[^1], reloaded)

    #Manually set the RandomX instance to null to make sure it's GC'able.
    blockchain.rx = nil
