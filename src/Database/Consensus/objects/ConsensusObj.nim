import sequtils
import algorithm
import sets, tables

import ../../../lib/[Errors, Hash]
import ../../../Wallet/MinerWallet

import ../../../objects/GlobalFunctionBoxObj

import ../../Filesystem/DB/ConsensusDB

import ../../Transactions/Transaction

import ../../Merit/State

import ../Elements/Elements
import TransactionStatusObj
export TransactionStatusObj

import SpamFilterObj

type Consensus* = object
  genesis*: Hash[256]

  functions*: GlobalFunctionBox
  db*: DB

  filters*: tuple[send: SpamFilter, data: SpamFilter]

  #[
  Cache of every malicious Merit Removal which has yet to be archived.
  After implicit Merit Removals, it was made so only one Merit Removal could be archived.
  That said, this remains a seq.
  If one MeritRemoval is no longer addable due to pruning one of the involved TXs, this lets us fall back on to another.
  This is an extreme edge case, yet a nice to have.
  We also already phrase all of this code around seqs.
  ]#
  malicious*: Table[uint16, seq[SignedMeritRemoval]]

  #Statuses of Transactions not yet out of Epochs.
  statuses*: Table[Hash[256], TransactionStatus]

  #Statuses which are close to becoming verified.
  #Every Transaction in this set is checked when new Blocks are added to see if they crossed the threshold.
  close*: HashSet[Hash[256]]
  #Transactions which haven't been mentioned in Epochs.
  unmentioned*: HashSet[Hash[256]]

  #Cache of signatures of unarchived elements.
  signatures*: Table[uint16, seq[BLSSignature]]
  #Archived nonces. Used to verify Block validity.
  archived*: Table[uint16, int]

proc newConsensusObj*(
  functions: GlobalFunctionBox,
  db: DB,
  state: State,
  sendDiff: uint16,
  dataDiff: uint16
): Consensus {.forceCheck: [].} =
  result = Consensus(
    functions: functions,
    db: db,

    filters: (
      send: newSpamFilterObj(sendDiff),
      data: newSpamFilterObj(dataDiff)
    ),
    malicious: db.loadMaliciousProofs(),

    statuses: initTable[Hash[256], TransactionStatus](),

    close: initHashSet[Hash[256]](),
    unmentioned: db.loadUnmentioned(),

    archived: initTable[uint16, int]()
  )

  try:
    result.genesis = result.functions.merit.getBlockByNonce(0).header.last
  except IndexError as e:
    panic("Couldn't get the genesis Block: " & e.msg)

  for h in 0 ..< state.holders.len:
    #Reload the filters.
    try:
      result.filters.send.update(state, uint16(h), result.db.loadSendDifficulty(uint16(h)))
    except DBReadError:
      #Happens when the holder never set a SendDifficulty.
      discard

    #In a different block in case they set a data difficulty but not a send difficulty.
    try:
      result.filters.data.update(state, uint16(h), result.db.loadDataDifficulty(uint16(h)))
    except DBReadError:
      discard

    #Reload the table of archived nonces.
    result.archived[uint16(h)] = result.db.loadArchived(uint16(h))

    #Reload the signatures.
    result.signatures[uint16(h)] = @[]
    try:
      for n in result.archived[uint16(h)] + 1 .. result.db.load(uint16(h)):
        result.signatures[uint16(h)].add(result.db.loadSignature(uint16(h), n))
    except KeyError as e:
      panic("Couldn't add a signature to the signature cache of a holder we just added: " & e.msg)
    except DBReadError as e:
      panic("Couldn't load a signature we know we have: " & e.msg)

  #Load unmentioned statuses.
  for hash in result.unmentioned:
    try:
      result.statuses[hash] = result.db.load(hash)
    except DBReadError as e:
      panic("Transaction not yet mentioned on the Blockchain doesn't have a status: " & e.msg)

proc loadCache*(
  consensus: var Consensus,
  state: State,
  pending: HashSet[Hash[256]]
) {.forceCheck: [].} =
  #Load statuses still in Epochs.
  for tx in pending:
    try:
      consensus.statuses[tx] = consensus.db.load(tx)
    except DBReadError as e:
      panic("Transaction archived on the Blockchain doesn't have a status: " & e.msg)

    #If this Transaction is close to being confirmed, add it to close.
    try:
      var merit: int = 0
      for holder in consensus.statuses[tx].holders:
        if not consensus.malicious.hasKey(holder):
          merit += state[holder, consensus.statuses[tx].epoch]
      if (
        (not consensus.statuses[tx].verified) and
        (merit >= state.nodeThresholdAt(consensus.statuses[tx].epoch) - 6)
      ):
        consensus.close.incl(tx)
    except KeyError as e:
      panic("Couldn't get a status we just added to the statuses table: " & e.msg)

proc setUnmentioned*(
  consensus: var Consensus,
  hash: Hash[256]
) {.forceCheck: [].} =
  consensus.unmentioned.incl(hash)
  consensus.db.addUnmentioned(hash)

#[
Save back a Transaction's Status.
I honestly forget why this is needed.
Since we only commit to the database at the end of every block, and the table should be updated with refs...
We should be able to use those two properties and just save them all back at once on block addition.
My only two guesses are:
1) A transaction system. We make changes to a status and then discard them on error.
2) We only want to save back statuses that have been changed.
If I had to guess, I'd assume its the second.
That said, we should be able to use a HashSet and remove this boiler plate.
-- Kayaba
]#
proc setStatus*(
  consensus: var Consensus,
  hash: Hash[256],
  status: TransactionStatus
) {.forceCheck: [].} =
  consensus.statuses[hash] = status
  consensus.db.save(hash, status)

#Get every Transaction with a status in the cache.
iterator cachedTransactions*(
  consensus: Consensus
): Hash[256] {.forceCheck: [].} =
  for hash in consensus.statuses.keys:
    yield hash

proc getStatus*(
  consensus: Consensus,
  hash: Hash[256]
): TransactionStatus {.forceCheck: [
  IndexError
].} =
  #Check the cache before loading from the database.
  if consensus.statuses.hasKey(hash):
    try:
      return consensus.statuses[hash]
    except KeyError as e:
      panic("Couldn't get a Status from the cache when the cache has the key: " & e.msg)

  try:
    result = consensus.db.load(hash)
  except DBReadError:
    raise newLoggedException(IndexError, "Transaction doesn't have a status.")

#[
Increment a Status's Epoch.
This happens when a Transaction isn't archived despite being in the mempool.
Only once its mentioned does its epoch get firmly set.
Even then, it's not too firm if conflicting transactions appear.
]#
proc incEpoch*(
  consensus: var Consensus,
  hash: Hash[256]
) {.forceCheck: [].} =
  var status: TransactionStatus
  try:
    status = consensus.getStatus(hash)
    inc(status.epoch)
  except ValueError:
    panic("Couldn't increment the Epoch of a Status with an invalid hash.")
  except IndexError:
    panic("Couldn't get the Status we're incrementing the Epoch of.")
  consensus.db.save(hash, status)

#Calculate a Transaction's Merit.
proc calculateMeritSingle(
  consensus: var Consensus,
  state: State,
  tx: Transaction,
  status: TransactionStatus,
  threshold: int
) {.forceCheck: [].} =
  #[
  If the Transaction is:
  - Already verified
  - Conflicting, and therefore needing to default
  Return. The only point in calculating this Merit is to verify when it gets enough Verifications.
  #So if it shouldn't be verified...
  ]#
  if status.verified or status.beaten or (status.competing and status.merit == -1):
    return

  #Calculate Merit, if needed.
  var merit: int = status.merit
  if merit == -1:
    merit = 0
    for holder in status.holders:
      #Skip malicious MeritHolders from Merit calculations.
      if not consensus.malicious.hasKey(holder):
        merit += state[holder, status.epoch]

  #Check if the Transaction crossed its threshold.
  if merit >= threshold:
    #This alone isn't enough. We also need to make sure all parents are verified.
    try:
      #[
      Claims claim Mints which are always verified.
      This will change, as according to the protocol, they're supposed to have a delay.
      That said, if we only add it post-delay, we don't need to track verified or not overall, so this code can remain.
      Datas have an input yet no parent in two cases:
      1) When the initial Data in a chain.
      2) When they're created from a Block.
      ]#
      if not (
        (tx of Claim) or
        (
          (tx of Data) and
          (cast[Data](tx).isFirstData or (tx.inputs[0].hash == consensus.genesis))
        )
      ):
        for input in tx.inputs:
          if not consensus.getStatus(input.hash).verified:
            return
    except IndexError as e:
      panic("Couldn't get the Status of a Transaction that was the parent to this Transaction: " & e.msg)

    #Mark the Transaction as verified.
    logInfo "Verified Transaction", hash = tx.hash
    status.verified = true
    consensus.db.save(tx.hash, status)
    consensus.functions.transactions.verify(tx.hash)
  elif merit >= state.nodeThresholdAt(status.epoch) - 6:
    consensus.close.incl(tx.hash)

#[
Calculate a Transaction's Merit. If it's verified, also check every descendant.
We don't update every Transaction in their tree order (and can't, depending on the tree).
This causes transactions to have 'unverified' parents, who become verified after we've already checked this child.
That's why we iterate over descendants.
We use a queue and the above calculateMeritSingle to avoid recursion.
]#
proc calculateMerit*(
  consensus: var Consensus,
  state: State,
  hash: Hash[256],
  statusArg: TransactionStatus,
  statusesOverride: TableRef[Hash[256], TransactionStatus] = nil
) {.forceCheck: [].} =
  var
    #Create the queue.
    children: seq[Hash[256]] = @[hash]
    child: Hash[256]
    tx: Transaction

    #[
    Initial status.
    This seems like a pointless optimization.
    It is technically faster, probably, but it bloats the function signature.
    That said, it is legitimate. It's used when we pre-calculate the status's Merit.
    ]#
    status: TransactionStatus = statusArg
    wasVerified: bool
    threshold: int

  #Iterate over said queue.
  while children.len != 0:
    child = children.pop()
    try:
      tx = consensus.functions.transactions.getTransaction(child)
      if child != hash:
        if statusesOverride.isNil:
          status = consensus.getStatus(child)
        else:
          status = statusesOverride[child]
    except KeyError:
      panic("Couldn't get the TransactionStatus for a Transaction we're reverting from the overriden cache.")
    except IndexError:
      panic("Couldn't get the Transaction/Status for a Transaction we're calculating the Merit of.")
    wasVerified = status.verified

    #If we're finalizing the Transaction, the best Transaction wins.
    #The below function ensures only the best TX gets passed here.
    if status.merit != -1:
      threshold = 0
    #Grab the node's threshold.
    else:
      threshold = state.nodeThresholdAt(status.epoch)

    consensus.calculateMeritSingle(
      state,
      tx,
      status,
      threshold
    )

    #If it only just become verified, iterate over its children.
    if (not wasVerified) and (status.verified):
      try:
        for o in 0 ..< max(tx.outputs.len, 1):
          children &= consensus.functions.transactions.getSpenders(newFundedInput(child, o))
      except IndexError as e:
        panic("Couldn't get a child Transaction/child Transaction's Status we've marked as a spender of this Transaction: " & e.msg)

#[
Unverify a Transaction.
This happens when a transaction dips under the protocol 'threshold' of 50.1%.
This generally would happen due to a MeritRemoval yet can theoretically happen due to epoch incrementing.
Since the protocol actually defines whatever competing Transaction with the most Merit as winning, this may be a poor decision.
There's discussion about when to call unverify here: https://github.com/MerosCrypto/Meros/issues/90.
]#
proc unverify*(
  consensus: var Consensus,
  hash: Hash[256],
  status: TransactionStatus,
  statusesOverride: TableRef[Hash[256], TransactionStatus] = nil
) {.forceCheck: [].} =
  var
    #Create a queue so we can unverify all children.
    #Matches the above calculateMerit function.
    children: seq[Hash[256]] = @[hash]
    child: Hash[256]
    tx: Transaction
    childStatus: TransactionStatus = status

  while children.len != 0:
    child = children.pop()
    try:
      tx = consensus.functions.transactions.getTransaction(child)
      if child != hash:
        if statusesOverride.isNil:
          childStatus = consensus.getStatus(child)
        else:
          childStatus = statusesOverride[child]
    except KeyError:
      panic("Couldn't get the TransactionStatus for a Transaction we're reverting from the overriden cache.")
    except IndexError:
      panic("Couldn't get the Transaction/Status for a Transaction we're calculating the Merit of.")

    #If this child wasn't verified, move on. None of its children are verified.
    if not childStatus.verified:
      continue

    #Since this child was verified, unverify it and grab its children.
    logWarn "Unverified Transaction", hash = child
    childStatus.verified = false
    consensus.db.save(child, childStatus)

    try:
      for o in 0 ..< max(tx.outputs.len, 1):
        children &= consensus.functions.transactions.getSpenders(newFundedInput(child, o))
    except IndexError as e:
      panic("Couldn't get a child Transaction/child Transaction's Status we've marked as a spender of this Transaction: " & e.msg)

    #Notify the Transactions DAG about the unverification.
    consensus.functions.transactions.unverify(child)

#Finalize the latest Epoch.
proc finalize*(
  consensus: var Consensus,
  state: State,
  txHashes: seq[Hash[256]]
): seq[seq[uint16]] {.forceCheck: [].} =
  type FinalizableTransaction = object
    tx: Transaction
    status: TransactionStatus
  var txs: seq[FinalizableTransaction] = @[]

  #Grab each TX and calculate their Merit.
  for i in 0 ..< txHashes.len:
    var status: TransactionStatus
    try:
      txs.add(FinalizableTransaction(
        tx: consensus.functions.transactions.getTransaction(txHashes[i])
      ))
      status = consensus.getStatus(txHashes[i])
    except IndexError as e:
      panic("Couldn't get the status of a Transaction (or the Transaction itself) we're finalizing: " & e.msg)

    #If this transaction was never mentioned on chain, prune it.
    #Happens when competitors occur yet only a subset is verified.
    if status.holders.len == status.pending.len:
      if status.verified:
        logWarn "Unverifying due to never being mentioned on chain", hash = txs[^1].tx.hash
        consensus.unverify(txs[^1].tx.hash, status)

      var
        #Discover the tree.
        tree: seq[Hash[256]] = consensus.functions.transactions.discoverTree(txs[^1].tx.hash)
        #Create a set of pruned Transactions as the tree can easily have duplicates.
        pruned: HashSet[Hash[256]] = initHashSet[Hash[256]]()

      #Prune the tree.
      for h in countdown(tree.len - 1, 0):
        if pruned.contains(tree[h]):
          continue
        pruned.incl(tree[h])

        #Remove the Transaction from RAM.
        consensus.statuses.del(tree[h])
        consensus.unmentioned.excl(tree[h])
        #Removes from the DB's copy of unmentioned.
        consensus.db.mention(tree[h])
        consensus.close.excl(tree[h])

        #Remove the Transaction from the Database.
        consensus.db.delete(tree[h])
        consensus.functions.transactions.prune(tree[h])

      txs.del(txs.len - 1)
      continue

    #Clear any pending Verifications.
    if status.holders.len != status.pending.len:
      status.holders = status.holders - status.pending
      status.pending = initHashSet[uint16]()
      status.packet = newSignedVerificationPacketObj(status.packet.hash)
      status.signatures = initTable[uint16, BLSSignature]()

    #Calculate the final Merit tally.
    status.merit = 0
    for holder in status.holders:
      #Only include holders on the Blockchain.
      #This also allows holders marked as malicious, if their removal has yet to be archived.
      if status.pending.contains(holder):
        status.holders.excl(holder)
        continue
      status.merit += state[holder, status.epoch]

    txs[^1].status = status

  #Sort from highest Merit to lowest.
  txs.sort(
    proc (
      a: FinalizableTransaction,
      b: FinalizableTransaction
    ): int =
      if a.status.merit > b.status.merit:
        result = 1
      elif a.status.merit < b.status.merit:
        result = -1
      else:
        if a.tx.hash < b.tx.hash:
          result = 1
        else:
          result = -1
    ,
    SortOrder.Descending
  )

  #[
  Iterate.
  If the transaction was verified or beaten, remove it.
  If the parents aren't verified, continue.
  ]#
  var
    used: HashSet[Input] = initHashSet[Input]()
    toVerify: seq[FinalizableTransaction] = @[]
    consideredVerified: HashSet[Hash[256]] = initHashSet[Hash[256]]()
    beatenAlready: HashSet[Hash[256]] = initHashSet[Hash[256]]()
    i: int = 0
  while txs.len != 0:
    i = i mod txs.len

    block thisTX:
      var finalizable: FinalizableTransaction = txs[i]
      if beatenAlready.contains(finalizable.tx.hash) or finalizable.status.beaten:
        consensus.statuses.del(finalizable.tx.hash)
        txs.delete(i)
        continue

      for input in finalizable.tx.inputs:
        if (finalizable.tx of Data) and ((input.hash == Hash[256]()) or (input.hash == consensus.genesis)):
          continue

        #This or parent was beaten.
        #Usage of finalizable.status.beaten works due to usage of a shared reference from getStatus.
        if used.contains(input) or finalizable.status.beaten:
          var toBeat: seq[Hash[256]] = consensus.functions.transactions.discoverTree(finalizable.tx.hash)
          for h in countdown(toBeat.len - 1, 0):
            let hash: Hash[256] = toBeat[h]
            #Needed for when a Transaction is finalizing with its descendant, and the parent is beaten.
            #Also needed due using discoverTree instead of discoverUnorderedTree.
            if beatenAlready.contains(hash):
              continue

            var status: TransactionStatus
            if hash == finalizable.tx.hash:
              status = finalizable.status
            else:
              try:
                status = consensus.getStatus(hash)
              except IndexError as e:
                panic("Couldn't get the status of a descendant of a Transaction we're finalizing: " & e.msg)

            consensus.functions.transactions.beat(hash)
            status.holders = status.holders - status.pending
            if status.holders.len == 0:
              #We should potentially prune after we finalize, enabling merging this block with the block executed before finalization.
              consensus.statuses.del(hash)
              consensus.unmentioned.excl(hash)
              consensus.db.mention(hash)
              consensus.close.excl(hash)

              consensus.db.delete(hash)
              consensus.functions.transactions.prune(hash)
            else:
              status.pending = initHashSet[uint16]()
              status.packet = newSignedVerificationPacketObj(status.packet.hash)
              status.signatures = initTable[uint16, BLSSignature]()
              status.beaten = true
              consensus.db.save(hash, status)
          beatenAlready = beatenAlready + toBeat.toHashSet()

          consensus.statuses.del(finalizable.tx.hash)
          txs.delete(i)
          break thisTX

        #Check the parent was verified.
        #If it wasn't beaten, yet isn't verified, it has yet to finalize due to sort ordering.
        #The first if handles the Claim case, where the parent won't have a TransactionStatus, as well as the cheap check.
        #The body and second if perform the more expensive, yet also necessary and most used, check.
        if not ((finalizable.tx of Claim) or consideredVerified.contains(input.hash)):
          var inputStatus: TransactionStatus
          try:
            inputStatus = consensus.getStatus(input.hash)
          except IndexError as e:
            panic("Couldn't get the status of an input of a Transaction we're finalizing: " & e.msg)

          if not inputStatus.verified:
            break thisTX

      #Since this Transaction can be verified, and will be, mark its inputs as used.
      for input in finalizable.tx.inputs:
        used.incl(input)

      #[
      Mark for verification/finalization.
      We could call calculateMerit, and then have descendants be verified along the way.
      The problem is a Transaction can compete with its own descendant.
      cM won't realize this, and will verify both.
      This loop here SHOULD properly unverify the competitor (see DescendantHighestVerifiedParent for evidence).
      That said, there is a temporary state where both are verified, before a warning about an unverification.
      We could use calculateMeritSingle, yet that's inefficient.
      This creation of a queue allows safe usage of cM.
      ]#
      toVerify.add(finalizable)
      consideredVerified.incl(finalizable.tx.hash)
      txs.delete(i)
      continue

    inc(i)

  #Now that we've marked the beaten TXs as so, run the tree verifications.
  for tx in toVerify:
    result.add(toSeq(tx.status.holders.items()))
    consensus.calculateMerit(state, tx.tx.hash, tx.status)
    consensus.db.save(tx.tx.hash, tx.status)
    consensus.statuses.del(tx.tx.hash)

#[
Delete a TransactionStatus.
This delete code doesn't match the delete code in the above function.
One of these is likely invalid, depending on where they're called.
This MUST be fixed if that's the case.
-- Kayaba
]#
proc delete*(
  consensus: var Consensus,
  hash: Hash[256]
) {.forceCheck: [].} =
  consensus.statuses.del(hash)
  consensus.close.excl(hash)
  consensus.unmentioned.excl(hash)
  consensus.db.delete(hash)

proc getElement*(
  consensus: Consensus,
  holder: uint16,
  nonce: int
): BlockElement {.forceCheck: [
  IndexError
].} =
  try:
    result = consensus.db.load(holder, nonce)
  except DBReadError:
    raise newLoggedException(IndexError, "Element " & $holder & " " & $nonce & " not found.")

#Get all pending Verification Packets/Elements, as well as the aggregate signature.
#Used to create a Block template.
proc getPending*(
  consensus: Consensus
): tuple[
  packets: seq[SignedVerificationPacket],
  elements: seq[BlockElement],
  aggregate: BLSSignature
] {.forceCheck: [].} =
  var included: HashSet[Hash[256]] = initHashSet[Hash[256]]()
  for status in consensus.statuses.values():
    #A status can be beaten here if the parent was beaten, yet the child has yet to finalize.
    if (status.packet.holders.len != 0) and (not status.beaten):
      result.packets.add(status.packet)
      included.incl(status.packet.hash)

  var signatures: seq[BLSSignature] = @[]
  try:
    for holder in consensus.signatures.keys():
      #[
      Skip over participants with Merit Removals.
      We need to include their Elements from the SignedMeritRemovals.
      This guarantees we don't include the same Element twice.
      Also a nice space saving optimization.
      ]#
      if consensus.malicious.hasKey(holder):
        continue

      if consensus.signatures[holder].len != 0:
        var nonce: int = consensus.archived[holder] + 1
        for s in 0 ..< consensus.signatures[holder].len:
          result.elements.add(consensus.db.load(holder, nonce + s))
          signatures.add(consensus.signatures[holder][s])
  except KeyError as e:
    panic("Couldn't get the nonce/signatures/MeritRemoval of a holder we know we have: " & e.msg)
  except DBReadError as e:
    panic("Couldn't get an Element we know we have: " & e.msg)

  #Add in Elements of Malicious Merit Holders to prove they're malicious.
  for holderMRs in consensus.malicious.values():
    for mr in holderMRs:
      #Skip over Competing Verification MRs. They're covered in the above packet code.
      if mr.element1 of Verification:
        continue
      #Add the Elements/signature and move on to the next holder.
      #There's no value in providing multiple Merit Removals for them.
      #There also is a risk if multiple Merit Removals share an Element we'll include a duplicate.
      #You can't argue with safety AND efficiency.
      result.elements.add(cast[BlockElement](mr.element2))
      if not mr.partial:
        result.elements.add(cast[BlockElement](mr.element1))
      signatures.add(mr.signature)
      break

  #Ensure all Transactions have had their parents been mentioned.
  #If they have a parent with no Verifications available, don't include them.
  var p: int = 0
  while p < result.packets.len:
    var tx: Transaction
    try:
      tx = consensus.functions.transactions.getTransaction(result.packets[p].hash)
    except IndexError as e:
      panic("Couldn't get a Transaction which has a packet: " & e.msg)

    if not (
      (tx of Claim) or
      (
        (tx of Data) and
        (cast[Data](tx).isFirstData or (tx.inputs[0].hash == consensus.genesis))
      )
    ):
      #Check if the parents were mentioned in a previous Block, or will be in this one.
      var mentioned: bool
      for input in tx.inputs:
        mentioned = included.contains(input.hash) or (not consensus.unmentioned.contains(input.hash))
        if not mentioned:
          break

      if not mentioned:
        result.packets.del(p)
        continue

    signatures.add(result.packets[p].signature)
    inc(p)

  result.aggregate = signatures.aggregate()
