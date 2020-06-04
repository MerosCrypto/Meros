import random

import ../../../../src/lib/Util
import ../../../../src/Wallet/MinerWallet

import ../../../../src/Database/Consensus/Elements/Elements
import ../../../../src/Database/Merit/[Difficulty, Block, Blockchain, State]

import ../../../Fuzzed
import ../../Consensus/Elements/TestElements
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
      #Miners we can remove Merit from.
      removable: seq[MinerWallet]
      #Selected miner to remove Merit from/for the next Block.
      miner: int

      #Elements we're adding to the Block.
      elements: seq[BlockElement]
      mining: Block

  noFuzzTest "Verify.":
    #Iterate over 80 'rounds'.
    for r in 1 .. 80:
      #Add the current Node Threshold to thresholds.
      thresholds.add(state.protocolThresholdAt(r))

      #Remove Merit from a random amount of Merit Holders every few Blocks.
      if rand(3) == 0:
        removable = miners
        for _ in 0 .. min(rand(2), high(miners)):
          miner = rand(high(removable))
          elements.add(
            newRandomMeritRemoval(
              state.reverseLookup(removable[miner].publicKey)
            )
          )
          removable.del(miner)

      #Decide if this is a nickname or new miner Block.
      if (miners.len == 0) or (rand(2) == 0):
        #New miner.
        miner = miners.len
        miners.add(newMinerWallet())

        #Create the Block with the new miner.
        mining = newBlankBlock(
          rx = blockchain.rx,
          last = blockchain.tail.header.hash,
          miner = miners[miner],
          elements = elements
        )
      else:
        #Grab a random miner.
        miner = rand(high(miners))

        #Create the Block with the existing miner.
        mining = newBlankBlock(
          rx = blockchain.rx,
          last = blockchain.tail.header.hash,
          nick = uint16(miner),
          miner = miners[miner],
          elements = elements
        )

      #Add it to the Blockchain and State.
      blockchain.processBlock(mining)
      discard state.processBlock(blockchain)

      #Commit the DB.
      db.commit(blockchain.height)

      #Clear the Elements.
      elements = @[]

      #Reload and compare the States.
      compare(state, newState(db, 30, blockchain))

    check:
      #Check that the State saved it had 0 Merit at the start.
      state.loadUnlocked(1) == 0
      #Check the threshold is just plus one.
      state.protocolThresholdAt(1) == 1

    #Check every existing threshold.
    for t in 1 .. thresholds.len:
      check state.protocolThresholdAt(t) == thresholds[t - 1]

    #Checking loading the Merit for the latest Block returns the State's Merit.
    check state.loadUnlocked(blockchain.height) == state.unlocked

    #Check future thresholds.
    for t in len(thresholds) + 2 ..< len(thresholds) + 82:
      check state.protocolThresholdAt(t) == min(state.unlocked + (t - 81), state.deadBlocks) div 2 + 1

    #Manually set the RandomX instance to null to make sure it's GC'able.
    blockchain.rx = nil
