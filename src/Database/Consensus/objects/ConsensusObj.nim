import algorithm, sets, tables

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
  #Cache of every malicious Merit Removal which has yet to be archived.
  malicious*: Table[uint16, seq[SignedMeritRemoval]]

  #Statuses of Transactions not yet out of Epochs.
  #Exported so the tests can test equality of this table.
  #That said, it shouldn't be required to export for the actual node.
  when defined(merosTests):
    statuses*: Table[Hash[256], TransactionStatus]
  else:
    statuses: Table[Hash[256], TransactionStatus]

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
  sendDiff: uint32,
  dataDiff: uint32
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

  #Load statuses still in Epochs.
  #Just like Epochs, this first requires loading the old last 5 Blocks and then the current last 5 Blocks.
  var
    height: int = functions.merit.getHeight()
    old: HashSet[Hash[256]] = initHashSet[Hash[256]]()
  try:
    for i in max(height - 10, 0) ..< height - 5:
      for packet in functions.merit.getBlockByNonce(i).body.packets:
        old.incl(packet.hash)

    for i in max(height - 5, 0) ..< height:
      #Skip old Transactions.
      for packet in functions.merit.getBlockByNonce(i).body.packets:
        if old.contains(packet.hash):
          continue

        try:
          result.statuses[packet.hash] = result.db.load(packet.hash)
        except DBReadError as e:
          panic("Transaction archived on the Blockchain doesn't have a status: " & e.msg)

        #If this Transaction is close to being confirmed, add it to close.
        try:
          var merit: int = 0
          for holder in result.statuses[packet.hash].holders:
            if not result.malicious.hasKey(holder):
              merit += state[holder, result.statuses[packet.hash].epoch]
          if (
            (not result.statuses[packet.hash].verified) and
            (merit >= state.nodeThresholdAt(result.statuses[packet.hash].epoch) - 6)
          ):
            result.close.incl(packet.hash)
        except KeyError as e:
          panic("Couldn't get a status we just added to the statuses table: " & e.msg)
  except IndexError as e:
    panic("Couldn't get a Block on the Blockchain: " & e.msg)

  #Load unmentioned statuses.
  for hash in result.unmentioned:
    try:
      result.statuses[hash] = result.db.load(hash)
    except DBReadError as e:
      panic("Transaction not yet mentioned on the Blockchain doesn't have a status: " & e.msg)

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
  - Impossible to verify as a conflicting transaction won
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

    #If we're finalizing the transaction, the best transaction wins.
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

#Finalize a family.
proc finalize*(
  consensus: var Consensus,
  state: State,
  inputs: HashSet[Input],
  family: seq[Hash[256]],
  cyclical: bool = false
) {.forceCheck: [
  UnfinalizedParents
].} =
  if not cyclical:
    #Check the inputs are finalized.
    for input in inputs:
      if (input.hash == Hash[256]()) or (input.hash == consensus.genesis):
        continue

      try:
        if consensus.getStatus(input.hash).merit == -1:
          raise newException(UnfinalizedParents, "Family requires another family to finalize first.")
      except IndexError as e:
        #This would generally be a panic, yet there is a single case where it isn't.
        #If this input is a Mint, it won't have a status.
        try:
          if not (consensus.functions.transactions.getTransaction(input.hash) of Mint):
            panic("Couldn't get the status of an input of a Transaction we're finalizing: " & e.msg)
        except IndexError as e:
          panic("Couldn't get a Transaction which is an input of a Transaction we're finalizing: " & e.msg)

  type FinalizableTransaction = object
    tx: Transaction
    status: TransactionStatus
  var txs: seq[FinalizableTransaction] = @[]

  #Grab each TX and calculate their Merit.
  for i in 0 ..< family.len:
    var status: TransactionStatus
    try:
      txs.add(FinalizableTransaction(
        tx: consensus.functions.transactions.getTransaction(family[i])
      ))
      status = consensus.getStatus(family[i])
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
        consensus.db.prune(tree[h])
        consensus.functions.transactions.prune(tree[h])

      txs.del(txs.len - 1)
      continue

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
  while txs.len != 0:
    var
      i: int = 0
      lenAtStart: int = txs.len
    while i < txs.len:
      block thisTX:
        var finalizable: FinalizableTransaction = txs[i]
        for input in finalizable.tx.inputs:
          if (finalizable.tx of Data) and ((input.hash == Hash[256]()) or (input.hash == consensus.genesis)):
            continue

          var
            inputStatus: TransactionStatus
            parentBeaten: bool = false
          if not (finalizable.tx of Claim):
            try:
              inputStatus = consensus.getStatus(input.hash)
            except IndexError as e:
              panic("Couldn't get the status of an input of a Transaction we're finalizing: " & e.msg)
            parentBeaten = inputStatus.beaten

          #This or parent was beaten.
          if used.contains(input) or parentBeaten:
            if finalizable.status.verified:
              consensus.unverify(finalizable.tx.hash, finalizable.status)
            consensus.functions.transactions.beat(finalizable.tx.hash)
            finalizable.status.beaten = true
            consensus.db.save(finalizable.tx.hash, finalizable.status)
            consensus.statuses.del(finalizable.tx.hash)
            txs.delete(i)
            break thisTX

          #Parent has yet to to have its status as verified/beaten checked due to sort ordering.
          if not ((finalizable.tx of Claim) or inputStatus.verified or consideredVerified.contains(input.hash)):
            break thisTX

        for input in finalizable.tx.inputs:
          used.incl(input)

        #[
        Mark for verification/finalization.
        Verify and finalize.
        We could call calculateMerit, and then have descendants be verified along the way.
        The problem is a transaction can compete with its own descendant.
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

    if lenAtStart == txs.len:
      panic("Couldn't finalize the TXs remaining in this family.")

  #Now that we've marked the beaten TXs as so, run the tree verifications.
  for tx in toVerify:
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
    if status.packet.holders.len != 0:
      result.packets.add(status.packet)
      included.incl(status.packet.hash)

  var signatures: seq[BLSSignature] = @[]
  try:
    for holder in consensus.signatures.keys():
      if consensus.malicious.hasKey(holder):
        result.elements.add(consensus.malicious[holder][0])
        signatures.add(consensus.malicious[holder][0].signature)
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

  var p: int = 0
  while p < result.packets.len:
    var
      tx: Transaction
      mentioned: bool

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
      block checkPredecessors:
        for input in tx.inputs:
          var status: TransactionStatus
          try:
            status = consensus.getStatus(input.hash)
          except IndexError as e:
            panic("Couldn't get the status of a Transaction before the current Transaction: " & e.msg)

          mentioned = included.contains(input.hash) or (not consensus.unmentioned.contains(input.hash))
          if not mentioned:
            break

        if not mentioned:
          result.packets.del(p)
          continue

    signatures.add(result.packets[p].signature)
    inc(p)

  result.aggregate = signatures.aggregate()
