#Fuzzing lib.
import ../../Fuzzed

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Verification libs.
import ../../../src/Database/Consensus/Elements/Verification
import ../../../src/Database/Consensus/Elements/VerificationPacket

#MeritRemoval lib.
import ../../../src/Database/Consensus/Elements/MeritRemoval as MeritRemovalFile

#Merit lib.
import ../../../src/Database/Merit/Merit

#Merit Testing functions.
import TestMerit

#Compare Merit lib.
import CompareMerit

#Tables standard lib.
import tables

#Random standard lib.
import random

suite "Epochs":
  setup:
    var
      #Database.
      db: DB = newTestDatabase()
      #Blockchain.
      blockchain: Blockchain = newBlockchain(db, "EPOCH_TEST", 1, uint64(1))
      #State.
      state: State = newState(db, 100, blockchain)
      #Epochs.
      epochs: Epochs = newEpochs(blockchain)

      #New Block.
      newBlock: Block
      #Rewards.
      rewards: seq[Reward]

  noFuzzTest "Reloaded Epochs.":
    var
      #Table of a hash to the block it first appeared on.
      first: Table[Hash[256], int] = initTable[Hash[256], int]()
      #Table of a hash to every nick which has already signed it.
      signed: Table[Hash[256], seq[uint16]] = initTable[Hash[256], seq[uint16]]()

      #List of MeritHolders.
      holders: seq[MinerWallet] = @[]
      #Miner we've selected.
      miner: uint16

      #Packets we've created.
      packets: seq[VerificationPacket]

    #Iterate over 20 'rounds'.
    for i in 1 .. 20:
      #If Merit has been mined, create packets.
      if i != 1:
        packets = @[]
        for _ in 0 ..< rand(20) + 2:
          packets.add(newValidVerificationPacket(state.holders))
          first[packets[^1].hash] = i
          signed[packets[^1].hash] = packets[^1].holders

        #Also create some packets using older hashes.
        for b in 1 ..< min(i, 5):
          for packet in blockchain[i - b].body.packets:
            if rand(2) == 0:
              if first[packet.hash] + 6 > i:
                continue

              if signed[packet.hash].len == holders.len:
                continue

              packets.add(newValidVerificationPacket(state.holders, signed[packet.hash], packet.hash))

      #Create the block using either a new miner or an existing one.
      if (i == 1) or (rand(1) == 0):
        holders.add(newMinerWallet())
        newBlock = newBlankBlock(
          rx = blockchain.rx,
          last = blockchain.tail.header.hash,
          miner = holders[^1],
          packets = packets
        )
      else:
        miner = uint16(rand(high(holders)))
        newBlock = newBlankBlock(
          rx = blockchain.rx,
          last = blockchain.tail.header.hash,
          nick = miner,
          miner = holders[miner],
          packets = packets
        )

      #Add it to the Blockchain.
      blockchain.processBlock(newBlock)

      #Add it to the State.
      discard state.processBlock(blockchain)

      #Shift the records onto the Epochs.
      discard epochs.shift(blockchain.tail)

      #Commit the DB.
      db.commit(blockchain.height)

      #Compare the Epochs.
      compare(epochs, newEpochs(blockchain))

    #Manually set the RandomX instance to null to make sure it's GC'able.
    blockchain.rx = nil

  noFuzzTest "Empty.":
    check(epochs.shift(newBlankBlock(rx = blockchain.rx)).calculate(state, initTable[uint16, MeritRemoval]()).len == 0)

    #Manually set the RandomX instance to null to make sure it's GC'able.
    blockchain.rx = nil

  noFuzzTest "Perfect 1000.":
    var
      #Hash.
      hash: Hash[256] = "".pad(32, char(128)).toHash(256)
      #MinerWallets.
      miners: seq[MinerWallet] = @[
        newMinerWallet(),
        newMinerWallet(),
        newMinerWallet()
      ]
      #SignedVerification.
      verif: SignedVerification
      #VerificationPacket.
      packet: SignedVerificationPacket = newSignedVerificationPacketObj(hash)

    for m in 0 ..< miners.len:
      #Give the miner Merit.
      blockchain.processBlock(newBlankBlock(
        rx = blockchain.rx,
        miner = miners[m]
      ))
      discard state.processBlock(blockchain)

      #Set the miner's nickname.
      miners[m].nick = uint16(m)

      #If the miner isn't the first, give them more Merit.
      #This provides the miners with 1, 2, and 2, respectively.
      #Below, we mine 4 Blocks with a mod 3.
      #That adds 2, 1, and 1, respectively, balancing everything out.
      if m != 0:
        blockchain.processBlock(newBlankBlock(
          rx = blockchain.rx,
          miner = miners[m]
        ))
        discard state.processBlock(blockchain)

      #Create the Verification.
      verif = newSignedVerificationObj(hash)
      miners[m].sign(verif)

      #Add it to the packet.
      packet.add(verif)

    #Shift on the packet.
    rewards = epochs.shift(newBlankBlock(
      rx = blockchain.rx,
      packets = cast[seq[VerificationPacket]](@[packet])
    )).calculate(state, initTable[uint16, MeritRemoval]())
    check(rewards.len == 0)

    #Shift 4 over.
    for e in 0 ..< 4:
      newBlock = newBlankBlock(
        rx = blockchain.rx,
        nick = uint16(e mod 3),
        miner = miners[e mod 3]
      )
      blockchain.processBlock(newBlock)
      discard state.processBlock(blockchain)

      rewards = epochs.shift(newBlock).calculate(state, initTable[uint16, MeritRemoval]())
      check(rewards.len == 0)

    #Next shift should result in a Rewards of 0: 334, 1: 333, and 2: 333.
    rewards = epochs.shift(newBlankBlock(rx = blockchain.rx)).calculate(state, initTable[uint16, MeritRemoval]())

    #Veirfy the length.
    check(rewards.len == 3)

    #Verify each nick is accurate and assigned to the right key.
    for r1 in 0 ..< rewards.len:
      check(rewards[r1].nick == uint16(r1))
      check(state.holders[r1] == miners[r1].publicKey)

    #Verify the scores.
    check(rewards[0].score == 334)
    check(rewards[1].score == 333)
    check(rewards[2].score == 333)

    #Manually set the RandomX instance to null to make sure it's GC'able.
    blockchain.rx = nil

  noFuzzTest "Single.":
    var
      #Hash.
      hash: Hash[256] = "".pad(32, char(128)).toHash(256)
      #MinerWallets.
      miner: MinerWallet = newMinerWallet()
      #SignedVerification.
      verif: SignedVerification
      #VerificationPacket.
      packet: SignedVerificationPacket = newSignedVerificationPacketObj(hash)

    #Give the miner Merit.
    blockchain.processBlock(newBlankBlock(
      rx = blockchain.rx,
      miner = miner
    ))
    discard state.processBlock(blockchain)

    #Set the miner's nickname.
    miner.nick = uint16(0)

    #Create the Verification.
    verif = newSignedVerificationObj(hash)
    miner.sign(verif)

    #Add it to the packet.
    packet.add(verif)

    #Shift on the packet.
    rewards = epochs.shift(newBlankBlock(
      rx = blockchain.rx,
      packets = cast[seq[VerificationPacket]](@[packet])
    )).calculate(state, initTable[uint16, MeritRemoval]())
    check(rewards.len == 0)

    #Shift 4 over.
    for e in 0 ..< 4:
      newBlock = newBlankBlock(
        rx = blockchain.rx,
        nick = uint16(0),
        miner = miner
      )
      blockchain.processBlock(newBlock)
      discard state.processBlock(blockchain)

      rewards = epochs.shift(newBlock).calculate(state, initTable[uint16, MeritRemoval]())
      check(rewards.len == 0)

    #Next shift should result in a Rewards of 0: 1000.
    rewards = epochs.shift(newBlankBlock(rx = blockchain.rx)).calculate(state, initTable[uint16, MeritRemoval]())
    check(rewards.len == 1)
    check(rewards[0].nick == 0)
    check(state.holders[0] == miner.publicKey)
    check(rewards[0].score == 1000)

    #Manually set the RandomX instance to null to make sure it's GC'able.
    blockchain.rx = nil

  noFuzzTest "Split.":
    var
      #Hash.
      hash: Hash[256] = "".pad(32, char(128)).toHash(256)
      #MinerWallets.
      miners: seq[MinerWallet] = @[
        newMinerWallet(),
        newMinerWallet()
      ]
      #SignedVerification.
      verif: SignedVerification
      #VerificationPacket.
      packet: SignedVerificationPacket

    for m in 0 ..< miners.len:
      #Give the miner Merit.
      blockchain.processBlock(newBlankBlock(
        rx = blockchain.rx,
        miner = miners[m]
      ))
      discard state.processBlock(blockchain)

      #Set the miner's nickname.
      miners[m].nick = uint16(m)

      #Create the Verification.
      verif = newSignedVerificationObj(hash)
      miners[m].sign(verif)

      #Add it to the packet.
      packet = newSignedVerificationPacketObj(hash)
      packet.add(verif)

      #Shift on the packet.
      rewards = epochs.shift(newBlankBlock(
        rx = blockchain.rx,
        packets = cast[seq[VerificationPacket]](@[packet])
      )).calculate(state, initTable[uint16, MeritRemoval]())
      check(rewards.len == 0)

    #Shift 3 over.
    for e in 0 ..< 3:
      if e < 2:
        newBlock = newBlankBlock(
          rx = blockchain.rx,
          nick = uint16(e),
          miner = miners[e]
        )
      else:
        newBlock = newBlankBlock(rx = blockchain.rx)
      blockchain.processBlock(newBlock)
      discard state.processBlock(blockchain)

      rewards = epochs.shift(newBlock).calculate(state, initTable[uint16, MeritRemoval]())
      check(rewards.len == 0)

    #Next shift should result in a Rewards of 0: 500, 1: 500, and 2: 500.
    rewards = epochs.shift(newBlankBlock(rx = blockchain.rx)).calculate(state, initTable[uint16, MeritRemoval]())

    #Veirfy the length.
    check(rewards.len == 2)

    #Verify each nick is accurate and assigned to the right key.
    for r1 in 0 ..< rewards.len:
      check(rewards[r1].nick == uint16(r1))
      check(state.holders[r1] == miners[r1].publicKey)

    #Verify the scores.
    check(rewards[0].score == 500)
    check(rewards[1].score == 500)

    #Manually set the RandomX instance to null to make sure it's GC'able.
    blockchain.rx = nil
