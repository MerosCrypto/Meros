import random
import sets, tables

import ../../../src/lib/[Errors, Util, Hash]
import ../../../src/Wallet/MinerWallet

import ../../../src/Database/Consensus/Elements/Elements
import ../../../src/Database/Merit/[Difficulty, Block, Blockchain, State]

import ../../Fuzzed
import TestMerit
import CompareMerit

const INITIAL_DIFFICULTY: uint64 = uint64(1)

suite "Blockchain":
  noFuzzTest "Reloaded and reverted Blockchain.":
    var
      db: DB = newTestDatabase()
      #Full copy of the Blocks independent of any database.
      blocks: seq[Block] = @[]
      #Blockchains.
      blockchains: seq[Blockchain] = @[newBlockchain(
        db,
        "BLOCKCHAIN_DB_TEST",
        30,
        INITIAL_DIFFICULTY
      )]
      #State. This is needed for the Blockchain's nickname table.
      state: State = newState(
        db,
        10,
        blockchains[0]
      )
      #Database copies.
      databases: seq[Table[string, string]] = @[]

      #Used Element nonces.
      elementNonces: Table[uint16, int] = initTable[uint16, int]()
      #Removals that have happened.
      removed: set[uint16] = {}

      packets: seq[VerificationPacket] = @[]
      elements: seq[BlockElement] = @[]
      toRemove: set[uint16] = {}
      miners: seq[MinerWallet]
      #Selected miner for the next Block.
      miner: uint16
      mining: Block

    proc getNonMaliciousHolder(): uint16 =
      result = uint16(rand(high(miners)))
      while removed.contains(result):
        result = uint16(rand(high(miners)))

    proc backupDatabase() =
      databases.add(initTable[string, string]())
      for key in db.merit.used:
        databases[^1][key] = db.lmdb.get("merit", key)

    #Iterate over 20 'rounds'.
    for i in 1 .. 20:
      if state.holders.len != removed.card:
        #Randomize the Packets.
        packets = @[]
        for _ in 0 ..< rand(0):#300):
          packets.add(newValidVerificationPacket(state.holders, removed))

        #Randomize the Elements/removals.
        elements = @[]
        toRemove = {}
        if rand(1) == 0:
          for _ in 0 ..< 3:
            var
              holder: uint16 = getNonMaliciousHolder()
              elementNonce: int
            try:
              elementNonce = elementNonces[holder]
            except KeyError:
              elementNonce = 0
            elementNonces[holder] = elementNonce + 1

            case rand(2):
              of 0:
                var sd: SignedSendDifficulty = newSignedSendDifficultyObj(elementNonce, uint16(rand(high(int16))))
                miners[holder].sign(sd)
                elements.add(sd)
              of 1:
                var dd: SignedDataDifficulty = newSignedDataDifficultyObj(elementNonce, uint16(rand(high(int16))))
                miners[holder].sign(dd)
                elements.add(dd)
              of 2:
                toRemove.incl(holder)
              else:
                panic("Generated a number outside of the provided range.")

      #Decide if this is a nickname or new miner Block.
      if (miners.len == removed.card) or (rand(2) == 0):
        #New miner.
        miner = uint16(miners.len)
        miners.add(newMinerWallet())
        miners[^1].nick = miner

        #Create the Block with the new miner.
        mining = newBlankBlock(
          rx = blockchains[^1].rx,
          uint32(0),
          blockchains[^1].tail.header.hash,
          char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
          miners[int(miner)],
          packets,
          elements,
          toRemove,
          time = max(getTime(), blockchains[^1].tail.header.time + 1)
        )
      else:
        #Grab a random miner.
        miner = uint16(rand(high(miners)))
        while removed.contains(miner):
          miner = uint16(rand(high(miners)))

        #Create the Block with the existing miner.
        mining = newBlankBlock(
          rx = blockchains[^1].rx,
          uint32(0),
          blockchains[^1].tail.header.hash,
          char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
          miner,
          miners[int(miner)],
          packets,
          elements,
          toRemove,
          time = max(getTime(), blockchains[^1].tail.header.time + 1)
        )

      #Perform the intial hash.
      blockchains[^1].rx.hash(miners[miner], mining.header, 0)

      #Mine it.
      var
        difficulty: uint64 = blockchains[^1].difficulties[^1]
        iter: int = 1
      if mining.header.newMiner:
        difficulty = difficulty * 11 div 10
      while mining.header.hash.overflows(difficulty):
        blockchains[^1].rx.hash(miners[miner], mining.header, mining.header.proof + 1)
        inc(iter)
        if iter mod 50 == 0:
          mining.header.time = max(getTime(), mining.header.time + 1)

      #Add it to the Blockchain and State.
      blockchains.add(blockchains[^1])
      blocks.add(mining)
      testBlockHeader(
        blockchains[^1].miners,
        state.holders,
        removed,
        blockchains[^1].tail.header,
        blockchains[^1].difficulties[^1],
        mining.header
      )
      blockchains[^1].processBlock(mining)
      discard state.processBlock(blockchains[^1])

      removed = removed + toRemove
      check removed == state.hasMR

      #Commit the DB.
      db.commit(blockchains[^1].height)

      #Backup the Database.
      backupDatabase()

      #Compare the Blockchains.
      compare(blockchains[^1], newBlockchain(
        db,
        "BLOCKCHAIN_DB_TEST",
        30,
        INITIAL_DIFFICULTY
      ))

    #Revert every chain and compare the Databases are identical at each step.
    for c in countdown(blockchains.len - 2, 1):
      #Revert the Blockchain to the specified height.
      blockchains[^1].revert(state, blockchains[c].height)
      db.commit(blockchains[^1].height)

      #Compare the Blockchains.
      compare(blockchains[^1], blockchains[c])

      #Verify every key in the Database is the same.
      #We use the key list in the last Database to verify key deletion.
      for key in db.merit.used:
        if databases[c - 1].hasKey(key):
          check db.lmdb.get("merit", key) == databases[c - 1][key]
        else:
          expect DBReadError:
            discard db.lmdb.get("merit", key)

    #Add all the Blocks back to the last chain.
    for b in 1 ..< blocks.len:
      blockchains[^1].processBlock(blocks[b])
      discard state.processBlock(blockchains[^1])
      db.commit(blockchains[^1].height)

      #Verify every key in the Database is what it's supposed to be.
      for key in db.merit.used:
        if databases[b].hasKey(key):
          check db.lmdb.get("merit", key) == databases[b][key]
        else:
          expect DBReadError:
            discard db.lmdb.get("merit", key)

    #Test one last reversion of the full chain.
    blockchains[^1].revert(state, blockchains[1].height)
    db.commit(blockchains[^1].height)

    #Compare the Blockchains.
    compare(blockchains[^1], blockchains[1])

    #Verify every key in the Database is the same.
    for key in db.merit.used:
      if databases[0].hasKey(key):
        check db.lmdb.get("merit", key) == databases[0][key]
      else:
        expect DBReadError:
          discard db.lmdb.get("merit", key)
