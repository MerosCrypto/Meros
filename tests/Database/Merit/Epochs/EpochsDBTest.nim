import random
import tables

import ../../../../src/lib/[Util, Hash]
import ../../../../src/Wallet/[MinerWallet, HDWallet]

import ../../../../src/Database/Transactions/Transactions
import ../../../../src/Database/Consensus/Elements/[VerificationPacket]
import ../../../../src/Database/Merit/Merit
import ../../../../src/Database/Consensus/Consensus

import ../../../Fuzzed
import ../TestMerit
import ../CompareMerit

proc randomHash(): Hash[256] =
  for b in 0 ..< 32:
    result.data[b] = uint8(rand(255))

suite "Epochs":
  setup:
    var
      db: DB = newTestDatabase()
      blockchain: Blockchain = newBlockchain(db, "EPOCH_TEST", 1, uint64(1))
      state: State = newState(db, 100, blockchain)
      transactions: Transactions = newTransactions(db, blockchain.genesis)
      functions: GlobalFunctionBox = newTestGlobalFunctionBox(addr blockchain, addr transactions)
      consensus: Consensus = newConsensus(functions, db, state, 3, 5)
    setTestConsensus(addr consensus)

    var
      epochs: Epochs = newEpochs(functions, blockchain, false)

      newBlock: Block
      rewards: seq[Reward]

  noFuzzTest "Reloaded Epochs.":
    var
      #Table of a hash to the block it first appeared on.
      first: Table[Hash[256], int] = initTable[Hash[256], int]()
      #Table of a hash to every nick which has already signed it.
      signed: Table[Hash[256], set[uint16]] = initTable[Hash[256], set[uint16]]()

      holders: seq[MinerWallet] = @[]
      miner: uint16

      packets: seq[VerificationPacket]

    #Iterate over 20 'rounds'.
    for i in 1 .. 20:
      #If Merit has been mined, create packets.
      if i != 1:
        packets = @[]
        for _ in 0 ..< rand(20) + 2:
          packets.add(newValidVerificationPacket(state.holders))
          let parent: Hash[256] = randomHash()
          transactions.add(
            Transaction(
              hash: packets[^1].hash,
              inputs: @[newInput(parent)]
            )
          )

          #Register the parent as finalized so Epochs doesn't think it's being fed non-canonical data.
          transactions.add(
            Transaction(
              hash: parent
            )
          )
          consensus.register(state, transactions[parent], blockchain.height)
          #Actually finalize it.
          let parentStatus: TransactionStatus = consensus.getStatus(parent)
          parentStatus.merit = 1
          consensus.setStatus(parent, parentStatus)

          #Register this Transaction.
          consensus.register(state, transactions[packets[^1].hash], blockchain.height)
          first[packets[^1].hash] = i
          signed[packets[^1].hash] = {}
          for h in packets[^1].holders:
            signed[packets[^1].hash].incl(h)

        #Also create some packets using older hashes.
        for b in 1 ..< min(i, 5):
          for packet in blockchain[i - b].body.packets:
            if rand(2) == 0:
              if first[packet.hash] + 6 > i:
                continue

              if signed[packet.hash].card == holders.len:
                continue

              packets.add(newValidVerificationPacket(state.holders, signed[packet.hash], packet.hash))

        #TODO: Also create competitors to test saving/loading of brought up transactions.
        #TODO: Also create descendants to test those being brought up as well.

        #Create an initial Data.
        let
          wallet: HDWallet = newHDWallet("".pad(32, char(i)))
          initial: Data = newData(Hash[256](), wallet.publicKey.serialize())
        echo "Data ", i, " ", initial.hash
        wallet.sign(initial)
        transactions.add(initial)
        packets.add(newValidVerificationPacket(state.holders, hash = initial.hash))
        consensus.register(state, initial, blockchain.height)
        first[initial.hash] = i
        signed[initial.hash] = {}
        for h in packets[^1].holders:
          signed[initial.hash].incl(h)

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

      blockchain.processBlock(newBlock)
      discard state.processBlock(blockchain)
      discard epochs.shift(blockchain.tail, uint(blockchain.height))
      db.commit(blockchain.height)
      compare(epochs, newEpochs(functions, blockchain))

    #Manually set the RandomX instance to null to make sure it's GC'able.
    blockchain.rx = nil
