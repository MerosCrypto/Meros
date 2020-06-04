import random
import algorithm
import sets, tables

import ../../../src/lib/[Util, Errors, Hash]
import ../../../src/Wallet/[MinerWallet, Wallet]

import ../../../src/Database/Filesystem/DB/TransactionsDB

import ../../../src/Database/Merit/Merit
import ../../../src/Database/Consensus/Elements/VerificationPacket
import ../../../src/Database/Transactions/Transactions

import ../../Fuzzed
import ../TestDatabase
import ../Merit/TestMerit
import CompareTransactions

suite "Transactions":
  setup:
    var
      db: DB = newTestDatabase()

      merit: Merit = newMerit(
        db,
        "TRANSACTIONS_TEST",
        30,
        uint64(0),
        100
      )

      transactions: Transactions = newTransactions(
        db,
        merit.blockchain
      )

      holder: MinerWallet = newMinerWallet()
      wallets: seq[Wallet] = @[]
      #Reverse lookup Table.
      walletsLookup: Table[EdPublicKey, int] = initTable[EdPublicKey, int]()

      #Planned Sends.
      plans: Table[int, seq[seq[SendOutput]]] = initTable[int, seq[seq[SendOutput]]]()
      #Amount of Meros needed for the planned Sends.
      needed: Table[int, int64] = initTable[int, int64]()

      #Copy of Transactions.
      txs: Table[Hash[256], Transaction] = initTable[Hash[256], Transaction]()
      #HashSet of the reverted Mints.
      revertedMints: HashSet[Hash[256]] = initHashSet[Hash[256]]()
      #Mapping of Transaction to Mint trees.
      mintTrees: Table[Hash[256], HashSet[Hash[256]]] = initTable[Hash[256], HashSet[Hash[256]]]()
      dataTips: Table[EdPublicKey, Hash[256]] = initTable[EdPublicKey, Hash[256]]()
      #Table of a hash to the Block it first appeared on.
      first: Table[Hash[256], int] = initTable[Hash[256], int]()

      #Copy of the Blockchain.
      blocks: seq[Block]

      #Variables for the next Block being mined.
      packets: seq[VerificationPacket] = @[]
      newBlock: Block

      #Rewards, indexed by Block hash.
      rewards: Table[Hash[256], seq[Reward]] = initTable[Hash[256], seq[Reward]]()

      #Trees reverted.
      reverted: HashSet[Hash[256]] = initHashSet[Hash[256]]()
      #Copy of spendable.
      spendable: Table[int, seq[FundedInput]] = initTable[int, seq[FundedInput]]()
      #Reverted Spendable. Defines what spendable should be after every reversion.
      revertedSpendable: Table[int, seq[FundedInput]] = initTable[int, seq[FundedInput]]()
      #Set of Transactions already reverted past in spendable.
      alreadyReverted: HashSet[Hash[256]] = initHashSet[Hash[256]]()

    proc add(
      tx: Transaction,
      mints: HashSet[Hash[256]]
    ) =
      #Create a VerificationPacket for the Transaction.
      packets.add(newVerificationPacketObj(tx.hash))
      packets[^1].holders.add(uint16(0))

      #Add the Transaction to our variables.
      txs[tx.hash] = tx
      mintTrees[tx.hash] = mints
      if tx of Data:
        dataTips[transactions.getSender(cast[Data](tx))] = tx.hash
      first[tx.hash] = merit.blockchain.height

      #Add the Transaction.
      case tx:
        of Claim as claim:
          transactions.add(
            claim,
            proc (
              h: uint16
            ): BLSPublicKey =
              holder.publicKey
          )
        of Send as send:
          transactions.add(send)
        of Data as data:
          transactions.add(data)
        else:
          panic("Adding an unknown Transaction type.")

      #Verify it. This will solely modify sendable, which only applies for Claim/Sends.
      transactions.verify(tx.hash)

    #Manually revert spendable a step.
    proc revertSpendable() =
      for w in 0 ..< wallets.len:
        var o: int = 0
        while o < revertedSpendable[w].len:
          if (mintTrees[revertedSpendable[w][o].hash] * reverted).len != 0:
            if not alreadyReverted.contains(revertedSpendable[w][o].hash):
              alreadyReverted.incl(revertedSpendable[w][o].hash)

              if txs[revertedSpendable[w][o].hash] of Send:
                #Restore every input this Transaction spent.
                #We don't have to check if the spent input has another spender, and therefore shouldn't be added back, as this test doesn't test that.
                for input in txs[revertedSpendable[w][o].hash].inputs:
                  revertedSpendable[
                    walletsLookup[
                      cast[SendOutput](
                        txs[input.hash].outputs[cast[FundedInput](input).nonce]
                      ).key
                    ]
                  ].add(cast[FundedInput](input))

            #Delete this output from spendable.
            revertedSpendable[w].del(o)
            continue
          inc(o)

    #Sort the UTXOs.
    proc sortUTXOs(
      x: FundedInput,
      y: FundedInput
    ): int =
      if x.hash < y.hash:
        return -1
      elif x.hash == y.hash:
        check x.nonce != y.nonce
        if x.nonce < y.nonce:
          return -1
        else:
          return 1
      else:
        return 1

    #Verify the Transactions DB pruned the right trees.
    proc verify(
      justReverted: Hash[256] = Hash[256]()
    ) =
      #Reload Transactions to fix its cache.
      commit(merit.blockchain.height)
      transactions = newTransactions(db, merit.blockchain)

      for hash in txs.keys():
        if (reverted * mintTrees[hash]).len != 0:
          expect IndexError:
            discard transactions[hash]
        else:
          discard transactions[hash]

      #Verify spendable was reverted accordingly.
      for w in 0 ..< wallets.len:
        var inputs: seq[FundedInput] = transactions.getUTXOs(wallets[w].publicKey)
        check inputs.len == revertedSpendable[w].len

        #Sort the UTXOs.
        inputs.sort(sortUTXOs)
        revertedSpendable[w].sort(sortUTXOs)

        for i in 0 ..< inputs.len:
          check:
            inputs[i].hash == revertedSpendable[w][i].hash
            inputs[i].nonce == revertedSpendable[w][i].nonce

      #Verify the Mint was pruned.
      if justReverted != Hash[256]():
        expect IndexError:
          discard transactions[justReverted]

    #Replay the Blockchain and Transactions from Block 10.
    proc replay() =
      #Reload Transactions to fix its cache.
      commit(merit.blockchain.height)
      transactions = newTransactions(db, merit.blockchain)

      for tx in txs.values():
        #Verify finalized Transactions are untouched.
        if first[tx.hash] <= 5:
          compare(transactions[tx.hash], tx)
        #Verify Claims/Sends (which don't have a mint > 10) and Datas are in the cache.
        elif (
          ((tx of Claim) or (tx of Send)) and
          ((mintTrees[tx.hash] * revertedMints).len == 0)
        ) or (tx of Data):
          compare(transactions.transactions[tx.hash], tx)
        #Verify everything else was pruned.
        else:
          expect IndexError:
            discard transactions[tx.hash]

      #Add back each Block and its Transactions.
      for b in 9 ..< blocks.len:
        #Add back the Transactions.
        for packet in blocks[b].body.packets:
          #Since we already verified:
          #- The correct Transactions were pruned.
          #- The correct Transactions are in the cache.
          #- The correct Transactions are in the database,
          #This is fine.
          try:
            discard transactions[packet.hash]
            continue
          except IndexError:
            discard

          var tx: Transaction = txs[packet.hash]
          case tx:
            of Claim as claim:
              transactions.add(
                claim,
                proc (
                  h: uint16
                ): BLSPublicKey =
                  holder.publicKey
              )
            of Send as send:
              transactions.add(send)
            of Data as data:
              transactions.add(data)
            else:
              panic("Replaying an unknown Transaction type.")
          transactions.verify(tx.hash)

        #Add back the Block.
        merit.processBlock(blocks[b])

        #Archive the Epoch.
        transactions.archive(newBlock, merit.postProcessBlock()[0])

        #Mint Meros.
        if b != blocks.len - 1:
          transactions.mint(blocks[b].header.hash, rewards[blocks[b].header.hash])

        #Commit the DB.
        commit(merit.blockchain.height)

      #Add back the last Transactions.
      for packet in blocks[^1].body.packets:
        try:
          discard transactions[packet.hash]
          continue
        except IndexError:
          discard

        var tx: Transaction = txs[packet.hash]
        case tx:
          of Claim as claim:
            transactions.add(
              claim,
              proc (
                h: uint16
              ): BLSPublicKey =
                holder.publicKey
            )
          of Send as send:
            transactions.add(send)
          of Data as data:
            transactions.add(data)
          else:
            panic("Replaying an unknown Transaction type.")
        transactions.verify(tx.hash)

      #Verify Transactions.
      for tx in txs.keys():
        try:
          compare(transactions[tx], txs[tx])
        except IndexError:
          check false

      #Verify spendable.
      for w in 0 ..< wallets.len:
        var inputs: seq[FundedInput] = transactions.getUTXOs(wallets[w].publicKey)

        #Sort the UTXOs.
        inputs.sort(sortUTXOs)
        spendable[w].sort(sortUTXOs)

        check inputs.len == spendable[w].len
        for i in 0 ..< inputs.len:
          check:
            inputs[i].hash == spendable[w][i].hash
            inputs[i].nonce == spendable[w][i].nonce

  noFuzzTest "Reloaded and reverted Transactions.":
    for b in 1 .. 30:
      #Create a random amount of Wallets.
      for _ in 0 ..< rand(2) + 2:
        wallets.add(newWallet(""))
        walletsLookup[wallets[^1].publicKey] = wallets.len - 1

      #For each Wallet, create a random amount of Transactions.
      for w in 0 ..< wallets.len:
        #Reset the planned Sends/needed Meros.
        plans[w] = @[]
        needed[w] = 0

        #Calculate how much Meros is currently available.
        for utxo in transactions.getUTXOs(wallets[w].publicKey):
          needed[w] -= int64(cast[SendOutput](transactions[utxo.hash].outputs[utxo.nonce]).amount)

        for t in 0 ..< rand(5):
          #Plan a Send.
          #The reason we only plan the Send is because we may need funds from the upcowming Mint for it.
          if rand(1) == 0:
            plans[w].add(@[])
            for o in 0 ..< rand(3) + 1:
              plans[w][^1].add(newSendOutput(wallets[rand(wallets.len - 1)].publicKey, uint64(rand(5000) + 1)))
              needed[w] += int64(plans[w][^1][^1].amount)

          #Create a Data.
          else:
            var
              dataStr: string = newString(rand(254) + 1)
              data: Data
            for c in 0 ..< dataStr.len:
              dataStr[c] = char(rand(255))

            try:
              discard dataTips[wallets[w].publicKey]
            except KeyError:
              data = newData(Hash[256](), wallets[w].publicKey.serialize())
              wallets[w].sign(data)
              data.mine(uint32(0))
              add(data, initHashSet[Hash[256]]())

            data = newData(dataTips[wallets[w].publicKey], dataStr)
            wallets[w].sign(data)
            data.mine(uint32(0))
            add(data, initHashSet[Hash[256]]())

        #Calculate the actual amount of needed Meros.
        needed[w] = max(needed[w], 0)

      #Create a Block.
      if merit.blockchain.height == 1:
        newBlock = newBlankBlock(
          rx = merit.blockchain.rx,
          last = merit.blockchain.tail.header.hash,
          miner = holder,
          packets = packets
        )
      else:
        newBlock = newBlankBlock(
          rx = merit.blockchain.rx,
          last = merit.blockchain.tail.header.hash,
          miner = holder,
          nick = uint16(0),
          packets = packets
        )

      #Clear packets.
      packets = @[]

      #Add it.
      merit.processBlock(newBlock)
      blocks.add(newBlock)

      #Archive the Epoch.
      transactions.archive(newBlock, merit.postProcessBlock()[0])

      #Create a Mint/Claim to fund all planned Sends.
      var claims: seq[Claim] = @[]
      rewards[newBlock.header.hash] = @[]
      for w in 0 ..< wallets.len:
        if needed[w] == 0:
          continue

        rewards[newBlock.header.hash].add(newReward(0, uint64(needed[w]) + uint64(rand(2000))))
        claims.add(newClaim(
          @[newFundedInput(newBlock.header.hash, rewards[newBlock.header.hash].len - 1)],
          wallets[w].publicKey
        ))
        holder.sign(claims[^1])
      transactions.mint(newBlock.header.hash, rewards[newBlock.header.hash])

      if b >= 10:
        revertedMints.incl(newBlock.header.hash)

      #Commit the DB.
      commit(merit.blockchain.height)

      #Compare the Transactions DAGs.
      var reloaded: Transactions = newTransactions(db, merit.blockchain)
      compare(transactions, reloaded)

      #Add the Claims.
      for claim in claims:
        add(claim, [newBlock.header.hash].toHashSet())

      #Create the planned Sends.
      for w in 0 ..< wallets.len:
        for outputs in plans[w].mitems():
          #Calculate the amount of needed Meros.
          var amount: int64 = 0
          for output in outputs:
            amount += int64(output.amount)

          #Grab the needed inputs.
          var
            i: int = 0
            inputs: seq[FundedInput] = transactions.getUTXOs(wallets[w].publicKey)
            mints: HashSet[Hash[256]] = initHashSet[Hash[256]]()
          while amount > int64(0):
            amount -= int64(cast[SendOutput](transactions[inputs[i].hash].outputs[inputs[i].nonce]).amount)
            mints = mints + mintTrees[inputs[i].hash]
            inc(i)
          while i != inputs.len:
            inputs.del(i)

          #Add a change output, if necessary.
          if amount != 0:
            outputs.add(newSendOutput(wallets[w].publicKey, uint64(-amount)))

          #Create and add the Send.
          var send: Send = newSend(inputs, outputs)
          wallets[w].sign(send)
          send.mine(uint32(0))
          add(send, mints)

    #Create one last Block for the latest Claims/Sends.
    newBlock = newBlankBlock(
      rx = merit.blockchain.rx,
      last = merit.blockchain.tail.header.hash,
      miner = holder,
      nick = uint16(0),
      packets = packets
    )
    merit.processBlock(newBlock)
    blocks.add(newBlock)
    transactions.archive(newBlock, merit.postProcessBlock()[0])
    commit(merit.blockchain.height)

    #Create a copy of spendable for every wallet.
    for w in 0 ..< wallets.len:
      spendable[w] = transactions.getUTXOs(wallets[w].publicKey)
    revertedSpendable = spendable

    #Revert each Block, verifying the various Transactions are deleted while leaving the others.
    while merit.blockchain.height != 10:
      var justReverted: Hash[256] = merit.blockchain.tail.header.hash
      reverted.incl(merit.blockchain.tail.header.hash)
      transactions.revert(merit.blockchain, merit.blockchain.height - 1)
      revertSpendable()
      verify(justReverted)
      merit.revert(merit.blockchain.height - 1)

    #Replay every Block/Transaction.
    replay()

    #Revert the entire DAG to Block 10.
    transactions.revert(merit.blockchain, 10)
    merit.revert(10)
    verify()

    #Replay every Block/Transaction again.
    replay()

    #Manually set the RandomX instance to null to make sure it's GC'able.
    merit.blockchain.rx = nil
