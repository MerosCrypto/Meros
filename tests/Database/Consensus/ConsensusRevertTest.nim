import random
import deques
import sets, tables

import ../../../src/lib/[Errors, Util, Hash]
import ../../../src/Wallet/[MinerWallet, Wallet]

import ../../../src/Database/Filesystem/DB/ConsensusDB

import ../../../src/Database/Merit/Merit
import ../../../src/Database/Consensus/Consensus
import ../../../src/Database/Transactions/Transactions

import ../../Fuzzed
import ../TestDatabase
import ../Merit/TestMerit
import CompareConsensus

suite "ConsensusRevert":
  setup:
    var
      initialSendDifficulty: uint16 = uint16(rand(high(int16)))
      initialDataDifficulty: uint16 = uint16(rand(high(int16)))

    var
      db: DB = newTestDatabase()

      merit: Merit = newMerit(
        db,
        "CONSENSUS_REVERT_TEST",
        30,
        uint64(1),
        75
      )

      transactions: Transactions = newTransactions(db, merit.blockchain)

      functions: GlobalFunctionBox = newTestGlobalFunctionBox(addr merit.blockchain, addr transactions)

      consensus: Consensus = newConsensus(
        functions,
        db,
        merit.state,
        initialSendDifficulty,
        initialDataDifficulty
      )
      full: Consensus
      reverted: Consensus

      holders: seq[MinerWallet] = @[
        newMinerWallet(),
        newMinerWallet(),
        newMinerWallet(),
        newMinerWallet()
      ]
      nonces: seq[int] = @[
        -1,
        -1,
        -1,
        -1
      ]

      wallets: seq[Wallet] = @[]

      #Planned Sends.
      plans: Table[int, seq[seq[SendOutput]]] = initTable[int, seq[seq[SendOutput]]]()
      #Amount of Meros needed for the planned Sends.
      needed: Table[int, int64] = initTable[int, int64]()

      #Copy of Transactions.
      txs: Table[Hash[256], Transaction] = initTable[Hash[256], Transaction]()
      utxos: Table[EdPublicKey, seq[FundedInput]] = initTable[EdPublicKey, seq[FundedInput]]()
      dataTips: Table[EdPublicKey, Hash[256]] = initTable[EdPublicKey, Hash[256]]()

      #Copy of verifications.
      verifications: Table[Hash[256], Table[Hash[256], HashSet[uint16]]] = initTable[Hash[256], Table[Hash[256], HashSet[uint16]]]()
      #The Epoch for each Transaction.
      epochs: Table[Hash[256], int] = initTable[Hash[256], int]()
      #Block number a Transaction became verified at.
      verified: Table[Hash[256], int] = initTable[Hash[256], int]()
      #Finalized statuses.
      finalizedStatuses: Table[Hash[256], TransactionStatus] = initTable[Hash[256], TransactionStatus]()
      #Pending statuses.
      pendingStatuses: Table[Hash[256], TransactionStatus] = initTable[Hash[256], TransactionStatus]()

      #Copy of the archived nonces at every step.
      archivedNonces: Table[Hash[256], Table[uint16, int]] = initTable[Hash[256], Table[uint16, int]]()
      #Copy of the pending signatures for the one holder with pending signatures.
      pendingElementsDisappearAt: Hash[256]
      pendingElementsRemoved: bool = true
      pendingElements: seq[Element] = @[]
      #Copy of each holder's Send/Data difficulties at each step.
      sendDifficulties: Table[Hash[256], Table[uint16, uint16]] = initTable[Hash[256], Table[uint16, uint16]]()
      dataDifficulties: Table[Hash[256], Table[uint16, uint16]] = initTable[Hash[256], Table[uint16, uint16]]()
      #Copy of the SpamFilters at every step.
      sendFilters: Table[Hash[256], SpamFilter] = initTable[Hash[256], SpamFilter]()
      dataFilters: Table[Hash[256], SpamFilter] = initTable[Hash[256], SpamFilter]()

      #Copy of the Blocks.
      blocks: seq[Block]
      #Copy of the rewards, indexed by Block hash.
      rewards: Table[Hash[256], seq[Reward]] = initTable[Hash[256], seq[Reward]]()

      #Temporary variables used whn creating a new Block.
      packets: seq[VerificationPacket] = @[]
      elements: seq[BlockElement] = @[]
      newBlock: Block

    proc add(
      tx: Transaction,
      requireVerification: bool = false
    ) =
      #Store a copy of the Transaction and update the Data tip, if this is a Data.
      txs[tx.hash] = tx
      if tx of Data:
        dataTips[transactions.getSender(cast[Data](tx))] = tx.hash

      case tx:
        of Claim as claim:
          for o in 0 ..< claim.outputs.len:
            utxos[cast[SendOutput](claim.outputs[o]).key].add(
              newFundedInput(claim.hash, o)
            )

          transactions.add(
            claim,
            proc (
              h: uint16
            ): BLSPublicKey {.gcsafe.} =
              {.gcsafe.}:
                holders[h].publicKey
          )
        of Send as send:
          for rawInput in send.inputs:
            var
              input: FundedInput = cast[FundedInput](rawInput)
              key: EdPublicKey = cast[SendOutput](txs[input.hash].outputs[input.nonce]).key
            for i in 0 ..< utxos[key].len:
              if (utxos[key][i].hash == input.hash) and (utxos[key][i].nonce == input.nonce):
                utxos[key].del(i)
                break

          for o in 0 ..< send.outputs.len:
            utxos[cast[SendOutput](send.outputs[o]).key].add(
              newFundedInput(send.hash, o)
            )

          transactions.add(send)
        of Data as data:
          transactions.add(data)
        else:
          panic("Adding an unknown Transaction type.")
      consensus.register(merit.state, tx, merit.blockchain.height)

      #Set the Epoch assigned.
      epochs[tx.hash] = consensus.getStatus(tx.hash).epoch

      #Create a VerificationPacket for the Transaction.
      packets.add(newSignedVerificationPacketObj(tx.hash))
      for holder in holders:
        if rand(1) == 0:
          continue
        if holder.initiated:
          var verif: SignedVerification = newSignedVerificationObj(tx.hash)
          holder.sign(verif)
          cast[SignedVerificationPacket](packets[^1]).add(verif)

          #Randomly add certain Verifications outside of the Blockchain.
          if rand(1) == 0:
            consensus.add(merit.state, verif)

      if packets[^1].holders.len == 0:
        var verif: SignedVerification = newSignedVerificationObj(tx.hash)
        holders[0].sign(verif)
        cast[SignedVerificationPacket](packets[^1]).add(verif)

    proc addBlock(
      last: bool = false
    ) =
      #Grab old Transactions in Epochs to verify as well.
      for epoch in merit.epochs:
        for tx in epoch.keys():
          if rand(6) != 0:
            continue

          #Create the packet.
          packets.add(newSignedVerificationPacketObj(tx))

          #Run against each Merit Holder.
          for h in 0 ..< holders.len:
            if (not holders[h].initiated) or epoch[tx].contains(uint16(h)) or (rand(3) != 0):
              continue

            #Add the holder.
            packets[^1].holders.add(uint16(h))

            #Create the SignedVerification.
            var verif: SignedVerification = newSignedVerificationObj(tx)
            holders[h].sign(verif)
            cast[SignedVerificationPacket](packets[^1]).add(verif)

          #If no holder was added, delete the packet.
          if packets[^1].holders.len == 0:
            packets.del(high(packets))

      #Create Send/Data difficulties.
      for h in 0 ..< holders.len:
        if not holders[h].initiated:
          continue

        if rand(2) == 0:
          var
            diff: uint16 = uint16(rand(high(int16)))
            sendDiff: SignedSendDifficulty

          inc(nonces[h])
          sendDiff = newSignedSendDifficultyObj(nonces[h], diff)
          holders[h].sign(sendDiff)
          consensus.add(merit.state, sendDiff)

          if (h != high(holders)) or (merit.blockchain.height < 80):
            elements.add(sendDiff)
          else:
            pendingElements.add(sendDiff)

            #Used as a temporary flag here.
            if pendingElementsRemoved:
              #These pendingElements are only pruned when a Block containing an archived Element is removed.
              #We need to iterate over the Blockchain to find the Block before the last Block archiving an Element from this holder.
              block findLastElement:
                for b in countdown(merit.blockchain.height - 1, 0):
                  for elem in merit.blockchain[b].body.elements:
                    if elem.holder == uint16(high(holders)):
                      pendingElementsDisappearAt = merit.blockchain[b - 1].header.hash
                      break findLastElement
              pendingElementsRemoved = false

        if rand(2) == 0:
          var
            diff: uint16 = uint16(rand(high(int16)))
            dataDiff: SignedDataDifficulty

          inc(nonces[h])
          dataDiff = newSignedDataDifficultyObj(nonces[h], diff)
          holders[h].sign(dataDiff)
          consensus.add(merit.state, dataDiff)

          if (h != holders.len - 1) or (merit.blockchain.height < 80):
            elements.add(dataDiff)
          else:
            pendingElements.add(dataDiff)

            if pendingElementsRemoved:
              block findLastElement:
                for b in countdown(merit.blockchain.height - 1, 0):
                  for elem in merit.blockchain[b].body.elements:
                    if elem.holder == uint16(high(holders)):
                      pendingElementsDisappearAt = merit.blockchain[b - 1].header.hash
                      break findLastElement
              pendingElementsRemoved = false

      #Create a Block.
      if merit.blockchain.height < holders.len + 1:
        newBlock = newBlankBlock(
          rx = merit.blockchain.rx,
          last = merit.blockchain.tail.header.hash,
          miner = holders[merit.blockchain.height - 1],
          packets = packets,
          elements = elements
        )
        holders[merit.blockchain.height - 1].nick = uint16(merit.blockchain.height - 1)
        holders[merit.blockchain.height - 1].initiated = true
      else:
        var holder: int = rand(high(holders) - 1)
        newBlock = newBlankBlock(
          rx = merit.blockchain.rx,
          last = merit.blockchain.tail.header.hash,
          miner = holders[holder],
          nick = uint16(holder),
          packets = packets,
          elements = elements
        )
      blocks.add(newBlock)

      #Clear packets.
      packets = @[]

      #Handle Merit Removals.
      consensus.remove(merit.blockchain, merit.state, newBlock.body.removals)

      #Add every packet.
      verifications[newBlock.header.hash] = initTable[Hash[256], HashSet[uint16]]()
      for packet in newBlock.body.packets:
        verifications[newBlock.header.hash][packet.hash] = packet.holders.toHashSet()
        consensus.add(merit.state, packet)

      #Add the Block to the Blockchain.
      merit.processBlock(newBlock)

      #Copy the State and add the Block to the Epochs and State.
      var
        rewardsState: State = merit.state
        epoch: Epoch
        changes: StateChanges
      (epoch, changes) = merit.postProcessBlock()

      #Archive the Epochs.
      consensus.archive(merit.state, newBlock.body.packets, newBlock.body.elements, epoch, changes)
      for tx in epoch.keys():
        finalizedStatuses[tx] = consensus.getStatus(tx)

      #Add the Elements.
      for elem in elements:
        case elem:
          of SendDifficulty as sendDiff:
            consensus.add(merit.state, sendDiff)
          of DataDifficulty as dataDiff:
            consensus.add(merit.state, dataDiff)
      elements = @[]

      #Archive the hashes handled by the popped Epoch.
      transactions.archive(newBlock, epoch)

      #Create a Mint/Claim to fund all planned Sends.
      var claims: Table[Hash[256], Claim] = initTable[Hash[256], Claim]()
      if not last:
        rewards[newBlock.header.hash] = @[]
        for w in 0 ..< wallets.len:
          if needed[w] == 0:
            continue

          rewards[newBlock.header.hash].add(newReward(0, uint64(needed[w]) + uint64(rand(2000))))
          var claim: Claim = newClaim(
            @[newFundedInput(newBlock.header.hash, rewards[newBlock.header.hash].len - 1)],
            wallets[w].publicKey
          )
          holders[0].sign(claim)
          claims[claim.hash] = claim
        transactions.mint(newBlock.header.hash, rewards[newBlock.header.hash])

      #Commit the DBs.
      commit(merit.blockchain.height)

      #Backup the archived nonces.
      archivedNonces[merit.blockchain.tail.header.hash] = consensus.archived

      #Backup the difficulties.
      sendDifficulties[merit.blockchain.tail.header.hash] = initTable[uint16, uint16]()
      dataDifficulties[merit.blockchain.tail.header.hash] = initTable[uint16, uint16]()
      for h in 0 ..< holders.len:
        try:
          sendDifficulties[merit.blockchain.tail.header.hash][uint16(h)] = consensus.db.loadSendDifficulty(uint16(h))
        except DBReadError:
          discard
        try:
          dataDifficulties[merit.blockchain.tail.header.hash][uint16(h)] = consensus.db.loadDataDifficulty(uint16(h))
        except DBReadError:
          discard

      #Add the Claims.
      if not last:
        for claim in claims.keys():
          add(claims[claim], true)

      #Iterate over every status in the cache. If any just became verified, mark it.
      for tx in consensus.statuses.keys():
        if claims.hasKey(tx) or verified.hasKey(tx):
          continue
        if consensus.statuses[tx].verified:
          verified[tx] = merit.blockchain.height

      #Since this test doesn't cause any competing transactions, mark any TX which just finalized as verified.
      for popped in epoch.keys():
        #Preserve any earlier height.
        if not verified.hasKey(popped):
          verified[popped] = merit.blockchain.height

    #Verify the reversion worked.
    proc verify() =
      var verifiers: Table[Hash[256], HashSet[uint16]] = initTable[Hash[256], HashSet[uint16]]()
      for b in merit.blockchain.height - 5 ..< merit.blockchain.height:
        for hash in verifications[merit.blockchain[b].header.hash].keys():
          if not verifiers.hasKey(hash):
            verifiers[hash] = initHashSet[uint16]()
          verifiers[hash] = verifiers[hash] + verifications[merit.blockchain[b].header.hash][hash]

      #Verify every Transaction has a valid status.
      for tx in txs.keys():
        try:
          #Check if the Transaction was pruned.
          discard transactions[tx]

          #If the Transaction is in the cache, make sure Consensus has the status cached with proper values.
          if transactions.transactions.hasKey(tx):
            check:
              consensus.statuses.hasKey(tx)
              consensus.statuses[tx].epoch == min(epochs[tx], merit.blockchain.height + 6)

            #Don't check competing since this test doesn't generate competing values.

            #Verify verified.
            if (
              #If this was never verified...
              (not verified.hasKey(tx)) or
              #Or it was yet wasn't verified at this point in time...
              (verified.hasKey(tx) and (merit.blockchain.height < verified[tx]))
            ):
              var
                meritSum: int = 0
                parentsVerified: bool = true

              #Calculate the Merit sum.
              for holder in consensus.statuses[tx].holders:
                meritSum += merit.state[holder, consensus.statuses[tx].epoch]

              #Handle the fact initial Datas and Claims always have verified inputs.
              if not (
                ((txs[tx] of Data) and (cast[Data](txs[tx]).isFirstData)) or
                (txs[tx] of Claim)
              ):
                #Check if the parents are verified.
                for input in txs[tx].inputs:
                  if not consensus.getStatus(input.hash).verified:
                    parentsVerified = false
                    break

              #Depending on when parents where verified, it could be verified under the node threshold.
              check (
                parentsVerified and
                (meritSum >= merit.state.nodeThresholdAt(consensus.statuses[tx].epoch))
              ) == consensus.statuses[tx].verified
            #It was verified at this point in time.
            else:
              check consensus.statuses[tx].verified

            #Don't test beaten for the same reason as competing.

            #Make sure there's a set for the verifiers.
            if not verifiers.hasKey(tx):
              verifiers[tx] = initHashSet[uint16]()

            #If the Transaction was finalized, pending, packet, and signatures will be blank.
            if finalizedStatuses.hasKey(tx):
              check:
                consensus.statuses[tx].pending.len == 0
                consensus.statuses[tx].packet.hash == tx
                consensus.statuses[tx].packet.holders.len == 0
                consensus.statuses[tx].packet.signature.isInf
                consensus.statuses[tx].signatures.len == 0
            #Else, pending/packet/signatures should be untouched.
            else:
              check pendingStatuses[tx].pending == consensus.statuses[tx].pending
              compare(pendingStatuses[tx].packet, consensus.statuses[tx].packet)

              check pendingStatuses[tx].signatures.len == consensus.statuses[tx].signatures.len
              for holder in pendingStatuses[tx].signatures.keys():
                check pendingStatuses[tx].signatures[holder] == consensus.statuses[tx].signatures[holder]

              verifiers[tx] = verifiers[tx] + consensus.statuses[tx].pending

            check:
              consensus.statuses[tx].holders == verifiers[tx]
              consensus.statuses[tx].merit == -1
          #If the Transaction was finalized and hasn't been reverted back to unfinalized, make sure the Consensus doesn't have it and its status is untouched.
          else:
            check not consensus.statuses.hasKey(tx)
            compare(consensus.getStatus(tx), finalizedStatuses[tx])
        #Transaction was pruned.
        except IndexError:
          #Verify the status was pruned.
          expect IndexError:
            discard consensus.getStatus(tx)

      #Verify the malicious table is untouched.
      for holder in full.malicious.keys():
        check full.malicious[holder].len == consensus.malicious[holder].len
        for mr in 0 ..< full.malicious[holder].len:
          compare(full.malicious[holder][mr], consensus.malicious[holder][mr])

      #Verify the SpamFilters were reverted.
      compare(consensus.filters.send, sendFilters[merit.blockchain.tail.header.hash])
      compare(consensus.filters.data, dataFilters[merit.blockchain.tail.header.hash])

      #Verify the archived nonces were reverted.
      check archivedNonces[merit.blockchain.tail.header.hash].len == consensus.archived.len
      for holder in archivedNonces[merit.blockchain.tail.header.hash].keys():
        check archivedNonces[merit.blockchain.tail.header.hash][holder] == consensus.archived[holder]

      #Check if the pending Elements have disappeared yet.
      if merit.blockchain.tail.header.hash == pendingElementsDisappearAt:
        pendingElementsRemoved = true

      #Verify the pending signatures are correct.
      if pendingElementsRemoved:
        check consensus.signatures[uint16(high(holders))].len == 0
      else:
        check consensus.signatures[uint16(high(holders))].len == pendingElements.len
        for s in 0 ..< pendingElements.len:
          var sig: BLSSignature
          case pendingElements[s]:
            of SignedSendDifficulty as sd:
              sig = sd.signature
            of SignedDataDifficulty as dd:
              sig = dd.signature
          check consensus.signatures[uint16(high(holders))][s].serialize() == sig.serialize()

      #Verify the difficulties are correct.
      for h in 0 ..< high(holders):
        try:
          check sendDifficulties[merit.blockchain.tail.header.hash][uint16(h)] == consensus.db.loadSendDifficulty(uint16(h))
        except KeyError:
          discard
        try:
          check dataDifficulties[merit.blockchain.tail.header.hash][uint16(h)] == consensus.db.loadDataDifficulty(uint16(h))
        except KeyError:
          discard

      #Check for the holder who has pending Elements.
      if pendingElementsRemoved:
        try:
          check sendDifficulties[merit.blockchain.tail.header.hash][uint16(high(holders))] == consensus.db.loadSendDifficulty(uint16(high(holders)))
        except KeyError:
          discard
        try:
          check dataDifficulties[merit.blockchain.tail.header.hash][uint16(high(holders))] == consensus.db.loadDataDifficulty(uint16(high(holders)))
        except KeyError:
          discard
      else:
        try:
          check sendDifficulties[blocks[^1].header.hash][uint16(high(holders))] == consensus.db.loadSendDifficulty(uint16(high(holders)))
        except KeyError:
          discard
        try:
          check dataDifficulties[blocks[^1].header.hash][uint16(high(holders))] == consensus.db.loadDataDifficulty(uint16(high(holders)))
        except KeyError:
          discard

      #Reload and compare the Consensus DAGs.
      compare(consensus, newConsensus(
        functions,
        db,
        merit.state,
        initialSendDifficulty,
        initialDataDifficulty
      ))

    proc copy(
      status: TransactionStatus
    ): TransactionStatus =
      result = newTransactionStatusObj(status.packet.hash, status.epoch)
      result.competing = status.competing
      result.verified = status.verified
      result.beaten = status.beaten
      result.holders = status.holders
      result.pending = status.pending
      result.packet = status.packet
      result.signatures = status.signatures
      result.merit = status.merit

    proc copy(): Consensus =
      result = consensus
      for tx in consensus.statuses.keys():
        result.statuses[tx] = copy(consensus.statuses[tx])

    #Replay from Block 50.
    proc replay() =
      #Reload Transactions to fix its cache.
      commit(merit.blockchain.height)
      transactions = newTransactions(db, merit.blockchain)

      #Add back each Block and its Transactions.
      for b in 49 ..< blocks.len:
        #Add back the Transactions and VerificationPackets.
        for packet in blocks[b].body.packets:
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
                ): BLSPublicKey {.gcsafe.} =
                  {.gcsafe.}:
                    holders[h].publicKey
              )
            of Send as send:
              transactions.add(send)
            of Data as data:
              transactions.add(data)
            else:
              panic("Replaying an unknown Transaction type.")
          consensus.register(merit.state, tx, merit.blockchain.height)

        #Handle Merit Removals.
        consensus.remove(merit.blockchain, merit.state, newBlock.body.removals)

        #Add every packet.
        for packet in blocks[b].body.packets:
          consensus.add(merit.state, packet)

        #Add back the Block.
        merit.processBlock(blocks[b])

        #Copy the State and Add the Block to the Epochs and State.
        var
          rewardsState: State = merit.state
          epoch: Epoch
          changes: StateChanges
        (epoch, changes) = merit.postProcessBlock()

        #Archive the Epochs.
        consensus.archive(merit.state, blocks[b].body.packets, blocks[b].body.elements, epoch, changes)

        #Add the elements.
        for elem in blocks[b].body.elements:
          case elem:
            of SendDifficulty as sendDiff:
              consensus.add(merit.state, sendDiff)
            of DataDifficulty as dataDiff:
              consensus.add(merit.state, dataDiff)

        #Archive the hashes handled by the popped Epoch.
        transactions.archive(blocks[b], epoch)

        if rewards.hasKey(blocks[b].header.hash):
          transactions.mint(blocks[b].header.hash, rewards[blocks[b].header.hash])

        #Commit the DBs.
        commit(merit.blockchain.height)

      #Add back the pending statuses.
      for tx in pendingStatuses.keys():
        if (
          #Datas are never pruned.
          (txs[tx] of Data) or (
            #Sends may not be pruned if they are part of a very old Mint tree.
            (txs[tx] of Send) and
            (consensus.getStatus(tx).pending.len != 0)
          )
        ):
          continue

        for holder in pendingStatuses[tx].signatures.keys():
          var verif: SignedVerification = newSignedVerificationObj(tx)
          verif.holder = holder
          verif.signature = pendingStatuses[tx].signatures[holder]
          consensus.add(merit.state, verif)

      #Add back the pending Elements.
      for elem in pendingElements:
        case elem:
          of SignedSendDifficulty as sd:
            consensus.add(merit.state, sd)
          of SignedDataDifficulty as dd:
            consensus.add(merit.state, dd)

      #Compare the replayed Consensus DAG with the full DAG.
      compare(consensus, full)

  noFuzzTest "Reverted Consensus.":
    #Add a Block so there's a Merit Holder with Merit.
    addBlock()

    for b in 1 .. 155:
      #Create a random amount of Wallets.
      for _ in 0 ..< rand(2) + 2:
        wallets.add(newWallet(""))
        utxos[wallets[^1].publicKey] = @[]

      #For each selected Wallet, create a random amount of Transactions.
      for w in 0 ..< wallets.len:
        #Reset the planned Sends/needed Meros.
        plans[w] = @[]
        needed[w] = 0

        #Skip random Wallets.
        if rand(1) == 0:
          continue

        #Calculate how much Meros is currently available.
        for utxo in utxos[wallets[w].publicKey]:
          needed[w] -= int64(cast[SendOutput](transactions[utxo.hash].outputs[utxo.nonce]).amount)

        for t in 0 ..< rand(2) + 1:
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
              add(data)

            data = newData(dataTips[wallets[w].publicKey], dataStr)
            wallets[w].sign(data)
            data.mine(uint32(0))
            add(data)

        #Calculate the actual amount of needed Meros.
        needed[w] = max(needed[w], 0)

      #Add a Block.
      addBlock()

      #Back up the filters.
      sendFilters[merit.blockchain.tail.header.hash] = consensus.filters.send
      dataFilters[merit.blockchain.tail.header.hash] = consensus.filters.data

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
            inputs: seq[FundedInput] = utxos[wallets[w].publicKey]
          while amount > int64(0):
            amount -= int64(cast[SendOutput](transactions[inputs[i].hash].outputs[inputs[i].nonce]).amount)
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
          add(send)

    #Create one last Block for the latest Claims/Sends.
    addBlock(true)

    #Add pending Signed Verifications to make sure they're reverted properly.
    for tx in consensus.statuses.keys():
      for h in 0 ..< holders.len:
        if (not consensus.statuses[tx].holders.contains(uint16(h))) and (rand(1) == 0):
          var verif: SignedVerification = newSignedVerificationObj(tx)
          holders[h].sign(verif)
          consensus.add(merit.state, verif)

    #Backup the pending statuses.
    for tx in consensus.statuses.keys():
      pendingStatuses[tx] = copy(consensus.statuses[tx])

    #Back up the full Consensus DAG.
    full = copy()

    #Revert, block by block.
    while merit.blockchain.height != 50:
      consensus.revert(merit.blockchain, merit.state, transactions, merit.blockchain.height - 1)
      transactions.revert(merit.blockchain, merit.blockchain.height - 1)
      merit.revert(merit.blockchain.height - 1)
      db.commit(merit.blockchain.height)
      transactions = newTransactions(db, merit.blockchain)
      consensus.postRevert(merit.blockchain, merit.state, transactions)
      db.commit(merit.blockchain.height)
      verify()

    #Back up the reverted Consensus DAG.
    reverted = copy()

    #Replay every Block/Transaction.
    replay()

    #Revert everything to Block 50 all at once.
    consensus.revert(merit.blockchain, merit.state, transactions, 50)
    transactions.revert(merit.blockchain, 50)
    merit.revert(50)
    db.commit(merit.blockchain.height)
    transactions = newTransactions(db, merit.blockchain)
    consensus.postRevert(merit.blockchain, merit.state, transactions)
    db.commit(merit.blockchain.height)
    verify()
    compare(consensus, reverted)

    #Replay every Block/Transaction again.
    replay()

    #Manually set the RandomX instance to null to make sure it's GC'able.
    merit.blockchain.rx = nil
