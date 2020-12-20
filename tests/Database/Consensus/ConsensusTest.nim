import random
import deques
import tables

import ../../../src/lib/[Util, Hash]
import ../../../src/Wallet/MinerWallet

import ../../../src/Database/Filesystem/DB/ConsensusDB

import ../../../src/Database/Merit/Merit
import ../../../src/Database/Consensus/Consensus
import ../../../src/Database/Transactions/Transactions

import ../../Fuzzed
import ../TestDatabase
import ../Merit/TestMerit
import CompareConsensus

suite "Consensus":
  midFuzzTest "Reloaded malicious table.":
    var
      db: DB = newTestDatabase()

      merit: Merit = newMerit(
        db,
        "CONSENSUS_DB_TEST",
        1,
        uint64(1),
        25
      )

      functions: GlobalFunctionBox = newTestGlobalFunctionBox(addr merit.blockchain, nil)

      consensus: Consensus = newConsensus(
        functions,
        db,
        merit.state,
        3,
        5
      )

      removed: set[uint16] = {}

    #Create Merit Holders.
    for h in 0 .. 500:
      merit.state.merit.add(1)
      merit.state.statuses.add(MeritStatus.Unlocked)
      consensus.archive(merit.state, @[], @[], newEpoch(), StateChanges(incd: uint16(high(merit.state.merit)), decd: -1))

    #Iterate over 100 actions.
    for a in 0 ..< 100:
      #Create three removals.
      for r in 0 ..< 3:
        var
          sendDiff: SendDifficulty = newSendDifficultyObj(rand(200000), uint16(rand(high(int16))))
          dataDiff: DataDifficulty = newDataDifficultyObj(sendDiff.nonce, uint16(rand(high(int16))))
          removal: SignedMeritRemoval = newSignedMeritRemoval(
            uint16(rand(500)),
            rand(1) == 0,
            sendDiff,
            dataDiff,
            newMinerWallet().sign("")
          )
        while removed.contains(removal.holder) and (not consensus.malicious.hasKey(removal.holder)):
          removal.holder = uint16(rand(500))
        removed.incl(removal.holder)

        sendDiff.holder = removal.holder
        dataDiff.holder = removal.holder

        consensus.flag(merit.blockchain, merit.state, removal.holder, removal)

      #Remove random MeritRemovals.
      var removals: set[uint16] = {}
      for holder in consensus.malicious.keys():
        if rand(2) == 0:
          removals.incl(holder)
      consensus.remove(merit.blockchain, merit.state, removals)

      #Reload and compare the Consensus DAGs.
      compare(consensus, newConsensus(
        functions,
        db,
        merit.state,
        3,
        5
      ))

    #Manually set the RandomX instance to null to make sure it's GC'able.
    merit.blockchain.rx = nil

  noFuzzTest "Reloaded Consensus.":
    var
      #Database.
      db: DB = newTestDatabase()

      #Merit.
      merit: Merit = newMerit(
        db,
        "CONSENSUS_DB_TEST",
        1,
        uint64(1),
        625
      )
      #Transactions.
      transactions: Transactions = newTransactions(
        db,
        merit.blockchain
      )

      #Functions.
      functions: GlobalFunctionBox = newTestGlobalFunctionBox(addr merit.blockchain, addr transactions)

      #Consensus.
      consensus: Consensus = newConsensus(
        functions,
        db,
        merit.state,
        3,
        5
      )

      #Merit Holders.
      holders: seq[MinerWallet] = @[]
      #Packets to include in the next Block.
      packets: seq[VerificationPacket] = @[]
      #Elements to include in the next Block.
      elements: seq[BlockElement] = @[]
      #Removals to include in the next Block.
      removals: set[uint16] = {}
      #List of Transactions we didn't add every SignedVerification for.
      unsigned: seq[Hash[256]] = @[]
      #SignedVerification used to generate signatures.
      sv: SignedVerification
      #Aggregate signature to include in the next Block.
      aggregate: BLSSignature = newBLSSignature()

    #Mine and add a Block.
    proc mineBlock() =
      #Grab a holder and create a Block.
      var
        miner: MinerWallet
        mining: Block
      if (rand(74) == 0) or (holders.len == merit.state.hasMR.card):
        miner = newMinerWallet()
        miner.nick = uint16(holders.len)
        holders.add(miner)

        mining = newBlankBlock(
          rx = merit.blockchain.rx,
          last = merit.blockchain.tail.header.hash,
          sketchSalt = char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
          miner = miner,
          packets = packets,
          elements = elements,
          removals = removals,
          aggregate = aggregate
        )
      else:
        var h: int = rand(high(holders))
        while merit.state.hasMR.contains(uint16(h)):
          h = rand(high(holders))
        miner = holders[h]

        mining = newBlankBlock(
          rx = merit.blockchain.rx,
          last = merit.blockchain.tail.header.hash,
          sketchSalt = char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
          nick = uint16(h),
          miner = miner,
          packets = packets,
          elements = elements,
          removals = removals,
          aggregate = aggregate
        )

      #Add every packet.
      for packet in mining.body.packets:
        consensus.add(merit.state, packet)

      #Remove Merit.
      consensus.remove(merit.blockchain, merit.state, removals)

      #Add a Block to the Blockchain to generate a holder.
      merit.processBlock(mining)

      #Copy the State.
      var rewardsState: State = merit.state

      #Add the Block to the Epochs and State.
      var
        epoch: Epoch
        changes: StateChanges
      (epoch, changes) = merit.postProcessBlock()

      #Archive the Epochs.
      consensus.archive(merit.state, mining.body.packets, mining.body.elements, epoch, changes)

      #Add the elements.
      for elem in elements:
        case elem:
          of SendDifficulty as sendDiff:
            consensus.add(merit.state, sendDiff)
          of DataDifficulty as dataDiff:
            consensus.add(merit.state, dataDiff)
      elements = @[]

      #Archive the hashes handled by the popped Epoch.
      transactions.archive(mining, epoch)

      #Commit the DBs.
      db.commit(merit.blockchain.height)

    #Mine a Block so there's a holder.
    mineBlock()

    #Compare the Consensus against the reloaded Consensus.
    proc compare() =
      compare(consensus, newConsensus(
        functions,
        db,
        merit.state,
        3,
        5
      ))

    #Iterate over 1250 'rounds'.
    for r in 1 .. 1250:
      #Clear the packets, unsigned table, and aggregate.
      packets = @[]
      unsigned = @[]
      aggregate = newBLSSignature()

      #Create a random amount of 'Transaction's.
      for _ in 0 ..< rand(2) + 1:
        #Don't create any if there's no valid Merit Holders.
        if holders.len == merit.state.hasMR.card:
          break

        #Register the Transaction.
        var tx: Transaction = Transaction()
        tx.hash = newRandomHash()
        transactions.transactions[tx.hash] = tx
        consensus.register(merit.state, tx, merit.blockchain.height)

        #Create a packet for the Transaction.
        packets.add(newVerificationPacketObj(tx.hash))

        #Grab random holders to sign the packet.
        for h in 0 ..< holders.len:
          if merit.state.hasMR.contains(uint16(h)) or (rand(1) == 0):
            continue

          packets[^1].holders.add(uint16(h))

          sv = newSignedVerificationObj(packets[^1].hash)
          holders[h].sign(sv)
          aggregate = if aggregate.isInf: sv.signature else: @[aggregate, sv.signature].aggregate()

          #Decide to add it to Consensus as a live SignedVerification or later as a VerificationPacket.
          if rand(3) == 0:
            if not unsigned.contains(tx.hash):
              unsigned.add(tx.hash)
          else:
            consensus.add(merit.state, sv)

        #Make sure at least one holder signed the packet.
        if packets[^1].holders.len == 0:
          packets[^1].holders.add(uint16(rand(high(holders))))
          while merit.state.hasMR.contains(packets[^1].holders[0]):
            packets[^1].holders[0] = uint16(rand(high(holders)))

          sv = newSignedVerificationObj(packets[^1].hash)
          holders[int(packets[^1].holders[0])].sign(sv)
          aggregate = if aggregate.isInf: sv.signature else: @[aggregate, sv.signature].aggregate()

          if rand(3) == 0:
            if not unsigned.contains(tx.hash):
              unsigned.add(tx.hash)
          else:
            consensus.add(merit.state, sv)

      #Iterate through the existing Epochs to add new Verifications to old Transactions.
      for epoch in merit.epochs:
        for tx in epoch.keys():
          if rand(2) == 0:
            continue

          #Create the packet.
          packets.add(newVerificationPacketObj(tx))

          #Run against each Merit Holder.
          for h in 0 ..< holders.len:
            if epoch[tx].contains(uint16(h)) or merit.state.hasMR.contains(uint16(h)) or (rand(2) == 0):
              continue

            #Add the holder.
            packets[^1].holders.add(uint16(h))

            #Create the SignedVerification.
            sv = newSignedVerificationObj(packets[^1].hash)
            holders[h].sign(sv)
            aggregate = @[aggregate, sv.signature].aggregate()

            if rand(3) == 0:
              if not unsigned.contains(tx):
                unsigned.add(tx)
            else:
              consensus.add(merit.state, sv)

          #If no holder was added, delete the packet.
          if packets[^1].holders == @[]:
            packets.del(high(packets))

      #Add Difficulties.
      if holders.len != merit.state.hasMR.card:
        var
          holder: int = rand(holders.len - 1)
          sendDiff: SignedSendDifficulty
          dataDiff: SignedDataDifficulty
        while merit.state.hasMR.contains(uint16(holder)):
          holder = rand(holders.len - 1)
        sendDiff = newSignedSendDifficultyObj(consensus.getArchivedNonce(uint16(holder)) + 1, uint16(rand(high(int16))))
        sendDiff.holder = uint16(holder)
        elements.add(sendDiff)

        holder = rand(holders.len - 1)
        while merit.state.hasMR.contains(uint16(holder)):
          holder = rand(holders.len - 1)
        dataDiff = newSignedDataDifficultyObj(consensus.getArchivedNonce(uint16(holder)) + 1, uint16(rand(high(int16))))
        dataDiff.holder = uint16(holder)
        elements.add(dataDiff)

      removals = {}
      if rand(125) == 0:
        #Add a Merit Removal.
        var holder: int = rand(holders.len - 1)
        while merit.state[uint16(holder), merit.state.processedBlocks] == 0:
          holder = rand(holders.len - 1)
        removals.incl(uint16(holder))

      #Mine the packets.
      mineBlock()

      #Compare the Consensus DAGs.
      compare()

    #Manually set the RandomX instance to null to make sure it's GC'able.
    merit.blockchain.rx = nil
