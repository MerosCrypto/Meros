import random

import ../../../src/lib/Util
import ../../../src/Wallet/MinerWallet

import ../../../src/Database/Merit/Merit

import ../../Fuzzed
import TestMerit

suite "Epochs":
  setup:
    var
      db: DB = newTestDatabase()
      blockchain: Blockchain = newBlockchain(db, "EPOCH_TEST", 1, uint64(1))
      state: State = newState(db, 100, blockchain)

  noFuzzTest "Empty.":
    check state.calculateRewards(@[], {}).len == 0

  noFuzzTest "Perfect 1000.":
    var miners: seq[MinerWallet] = @[
      newMinerWallet(),
      newMinerWallet(),
      newMinerWallet()
    ]

    for m in 0 ..< miners.len:
      #Give the miners Merit.
      blockchain.processBlock(newBlankBlock(
        rx = blockchain.rx,
        miner = miners[m]
      ))
      discard state.processBlock(blockchain)

      #Set the miner's nickname.
      miners[m].nick = uint16(m)

    #Claim they all participated in a Transaction.
    #This should result in an equal split of 0: 334, 1: 333, and 2: 333.
    var rewards: seq[Reward] = state.calculateRewards(@[@[0'u16, 1, 2]], {})

    #Verify the length.
    check rewards.len == 3

    #Verify each nick is accurate and assigned to the right key.
    for r1 in 0 ..< rewards.len:
      check:
        rewards[r1].nick == uint16(r1)
        state.holders[r1] == miners[r1].publicKey

    #Verify the scores.
    check:
      rewards[0].score == 334
      rewards[1].score == 333
      rewards[2].score == 333

    #Manually set the RandomX instance to null to make sure it's GC'able.
    blockchain.rx = nil

  noFuzzTest "Single.":
    var miner: MinerWallet = newMinerWallet()

    #Give the miner Merit.
    blockchain.processBlock(newBlankBlock(
      rx = blockchain.rx,
      miner = miner
    ))
    discard state.processBlock(blockchain)

    #Set the miner's nickname.
    miner.nick = uint16(0)

    #Should result in a Rewards of 0: 1000.
    var rewards: seq[Reward] = state.calculateRewards(@[@[0'u16]], {})
    check:
      rewards.len == 1
      rewards[0].nick == 0
      state.holders[0] == miner.publicKey
      rewards[0].score == 1000

    #Manually set the RandomX instance to null to make sure it's GC'able.
    blockchain.rx = nil

  noFuzzTest "Split.":
    var miners: seq[MinerWallet] = @[
      newMinerWallet(),
      newMinerWallet()
    ]

    for m in 0 ..< miners.len:
      #Give the miner Merit.
      blockchain.processBlock(newBlankBlock(
        rx = blockchain.rx,
        miner = miners[m]
      ))
      discard state.processBlock(blockchain)

      #Set the miner's nickname.
      miners[m].nick = uint16(m)

    #Should result in a Rewards of 0: 500 and 1: 500.
    var rewards: seq[Reward] = state.calculateRewards(@[@[0'u16, 1'u16]], {})

    #Verify the length.
    check rewards.len == 2

    #Verify each nick is accurate and assigned to the right key.
    for r1 in 0 ..< rewards.len:
      check:
        rewards[r1].nick == uint16(r1)
        state.holders[r1] == miners[r1].publicKey

    #Verify the scores.
    check:
      rewards[0].score == 500
      rewards[1].score == 500

    #Manually set the RandomX instance to null to make sure it's GC'able.
    blockchain.rx = nil
