import random

import ../../../../src/lib/Util
import ../../../../src/Wallet/MinerWallet

import ../../../../src/Database/Consensus/Elements/Elements
import ../../../../src/Database/Merit/[Difficulty, Block, Blockchain, State]

import ../../../Fuzzed
import ../TestMerit
import ../CompareMerit

suite "StateDB":
  setup:
    var
      db: DB = newTestDatabase()
      blockchain: Blockchain = newBlockchain(
        db,
        "STATE_DB_TEST",
        30,
        uint64(1)
      )
      state: State = newState(db, 30, blockchain)

      thresholds: seq[int] = @[]

      miners: seq[MinerWallet] = @[]
      #Miners we removed Merit from.
      removed: set[uint16] = {}
      #Selected miner to remove Merit from/for the next Block.
      miner: uint16

      #Miners we're about to remove Merit from.
      toRemove: set[uint16] = {}
      mining: Block

  noFuzzTest "Verify.":
    #Iterate over 80 'rounds'.
    for r in 1 .. 80:
      #Add the current Node Threshold to thresholds.
      thresholds.add(state.nodeThresholdAt(r))

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
          miner = miners[miner],
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
          miner = miners[miner],
          removals = toRemove
        )

      #Add it to the Blockchain and State.
      blockchain.processBlock(mining)
      discard state.processBlock(blockchain)

      #Commit the DB.
      db.commit(blockchain.height)

      #Clear the pending removals.
      toRemove = {}

      #Verify the malicious Merit Holders list is accurate.
      check removed == state.hasMR

      #Reload and compare the States.
      compare(state, newState(db, 30, blockchain))

    check:
      #Check that the State saved it had 0 Merit at the start.
      state.loadCounted(1) == 0
      #Check the threshold is just five.
      state.nodeThresholdAt(1) == 5

    #Check every existing threshold.
    for t in 1 .. thresholds.len:
      check state.nodeThresholdAt(t) == thresholds[t - 1]

    #Checking loading the Merit for the latest Block returns the State's Merit.
    check state.loadCounted(blockchain.height) == state.counted

    #Manually set the RandomX instance to null to make sure it's GC'able.
    blockchain.rx = nil
