include MainConsensus

#Creates and publishes a Verification.
proc verify(
  wallet: WalletDB,
  functions: GlobalFunctionBox,
  merit: Merit,
  consensus: ref Consensus,
  transaction: Transaction
) {.forceCheck: [], async.} =
  #Grab the Transaction's status.
  var status: TransactionStatus
  try:
    status = consensus[].getStatus(transaction.hash)
  except IndexError as e:
    panic("Asked to verify a Transaction without a Status: " & e.msg)

  #Make sure this Transaction can be verified.
  if status.beaten:
    return

  #Make sure we're a Miner with Merit.
  if wallet.miner.initiated and (merit.state.merit[wallet.miner.nick] > 0):
    #Inform the WalletDB were verifying a Transaction.
    try:
      wallet.verifyTransaction(transaction)
    #We already verified a competitor.
    except ValueError:
      return

    #Verify the Transaction.
    var verif: SignedVerification = newSignedVerificationObj(transaction.hash)
    wallet.miner.sign(verif)

    #Add the Verification, which calls broadcast.
    try:
      await functions.consensus.addSignedVerification(verif)
    except ValueError as e:
      panic("Created a Verification with an invalid signature: " & e.msg)
    except DataExists as e:
      panic("Created a Verification which already exists: " & e.msg)
    except Exception as e:
      panic("addSignedVerification threw an exception despite catching all errors: " & e.msg)

proc syncPrevious(
  functions: GlobalFunctionBox,
  transactions: Transactions,
  network: Network,
  final: Transaction
) {.forceCheck: [
  ValueError,
  DataMissing
], async.} =
  var
    toProcess: seq[Hash[256]] = @[]
    queue: seq[Transaction] = @[]
    current: Hash[256]
    tx: Transaction
  for input in final.inputs:
    toProcess.add(input.hash)

  #This function should NOT run any async tasks if there's no previous tasks to sync.
  while toProcess.len != 0:
    current = toProcess.pop()
    if (final of Data) and ((current == Hash[256]()) or (current == transactions.genesis)):
      continue

    try:
      discard transactions[current]
      continue
    except IndexError:
      discard

    try:
      tx = await syncAwait network.syncManager.syncTransaction(current)
    except DataMissing as e:
      raise e
    except Exception as e:
      panic("syncTransaction threw an error despite catching all errors: " & e.msg)

    if (
      ((final of Send) and (not ((tx of Claim) or (tx of Send)))) or
      ((final of Data) and (not (tx of Data)))
    ):
      raise newLoggedException(ValueError, "Transaction has an invalid input.")

    if (
      (
        (tx of Send) and
        cast[Send](tx).argon.overflows(cast[Send](tx).getDifficultyFactor() * functions.consensus.getSendDifficulty())
      ) or (
        (tx of Data) and
        cast[Data](tx).argon.overflows(cast[Data](tx).getDifficultyFactor() * functions.consensus.getDataDifficulty())
      )
    ):
      raise newLoggedException(ValueError, "Transaction doesn't pass the spam check.")

    queue.add(tx)

    if not (tx of Claim):
      for input in tx.inputs:
        toProcess.add(input.hash)

  while queue.len != 0:
    try:
      var next: Transaction = queue.pop()
      case next:
        of Claim as claim:
          functions.transactions.addClaim(claim, true)
        of Send as send:
          await functions.transactions.addSend(send, true)
        of Data as data:
          await functions.transactions.addData(data, true)
        else:
          panic("Synced a Transaction input that isn't a valid input.")
    except ValueError as e:
      raise e
    #Can happen either due to async conditions or due to a duplicate in the discovered tree.
    #As the tree must be ordered, the first can't really be fixed.
    #Best we can do is optimize with a HashSet so we skip this check, except due to async.
    except DataExists:
      discard
    except Exception as e:
      panic("Adding a Transaction raised despite catching every error: " & e.msg)

proc mainTransactions(
  database: DB,
  wallet: WalletDB,
  functions: GlobalFunctionBox,
  merit: Merit,
  consensus: ref Consensus,
  transactions: ref Transactions,
  network: ref Network
) {.forceCheck: [].} =
  transactions[] = newTransactions(database, merit.blockchain)

  functions.transactions.getTransaction = proc (
    hash: Hash[256]
  ): Transaction {.forceCheck: [
    IndexError
  ].} =
    try:
      result = transactions[][hash]
    except IndexError as e:
      raise e

  functions.transactions.getUTXOs = proc (
    key: EdPublicKey
  ): seq[FundedInput] {.forceCheck: [].} =
    transactions[].getUTXOs(key)

  functions.transactions.getSpenders = proc (
    input: Input
  ): seq[Hash[256]] {.forceCheck: [].} =
    transactions[].loadSpenders(input)

  functions.transactions.getAndPruneFamilyUnsafe = proc (
    input: Input
  ): HashSet[Input] {.forceCheck: [].} =
    transactions.families.getAndPruneFamilyUnsafe(input)

  functions.transactions.addClaim = proc (
    claim: Claim,
    syncing: bool = false
  ) {.forceCheck: [
    ValueError,
    DataExists
  ].} =
    logInfo "New Claim", hash = claim.hash

    try:
      transactions[].add(claim, functions.merit.getPublicKey)
    #Passing a function which can raise IndexError raised one.
    #One of the faults in Nim's effect system.
    except IndexError as e:
      panic("Passing a function which can raise an IndexError raised an IndexError: " & e.msg)
    except ValueError as e:
      raise e
    except DataExists as e:
      raise e

    consensus[].register(merit.state, claim, merit.blockchain.height)
    logInfo "Added Claim", hash = claim.hash

    if not syncing:
      functions.network.broadcast(MessageType.Claim, claim.serialize())

      try:
        asyncCheck verify(wallet, functions, merit, consensus, claim)
      except Exception as e:
        panic("Verify threw an Exception despite not naturally throwing anything: " & e.msg)

  functions.transactions.addSend = proc (
    send: Send,
    syncing: bool = false
  ) {.forceCheck: [
    ValueError,
    DataExists
  ], async.} =
    logInfo "New Send", hash = send.hash

    try:
      await syncPrevious(functions, transactions[], network[], send)
    except ValueError as e:
      raise e
    except DataExists as e:
      raise e
    except DataMissing:
      raise newLoggedException(ValueError, "Transaction has a non-existent input.")
    except Exception as e:
      panic("syncPrevious threw an Exception despite catching everything: " & e.msg)

    #Any further usage of async risks a race condition where we may double-process a transaction depending on timing.

    try:
      transactions[].add(send)
    except ValueError as e:
      raise e
    except DataExists as e:
      raise e

    consensus[].register(merit.state, send, merit.blockchain.height)
    logInfo "Added Send", hash = send.hash

    if not syncing:
      functions.network.broadcast(
        MessageType.Send,
        send.serialize()
      )

      try:
        asyncCheck verify(wallet, functions, merit, consensus, send)
      except Exception as e:
        panic("Verify threw an Exception despite not naturally throwing anything: " & e.msg)

  functions.transactions.addData = proc (
    data: Data,
    syncing: bool = false
  ) {.forceCheck: [
    ValueError,
    DataExists
  ], async.} =
    logInfo "New Data", hash = data.hash

    try:
      await syncPrevious(functions, transactions[], network[], data)
    except ValueError as e:
      raise e
    except DataExists as e:
      raise e
    except DataMissing:
      raise newLoggedException(ValueError, "Transaction has a non-existent input.")
    except Exception as e:
      panic("syncPrevious threw an Exception despite catching everything: " & e.msg)

    #Any further usage of async risks a race condition where we may double-process a transaction depending on timing.

    try:
      transactions[].add(data)
    except ValueError as e:
      raise e
    except DataExists as e:
      raise e

    consensus[].register(merit.state, data, merit.blockchain.height)
    logInfo "Added Data", hash = data.hash

    if not syncing:
      functions.network.broadcast(
        MessageType.Data,
        data.serialize()
      )

      try:
        asyncCheck verify(wallet, functions, merit, consensus, data)
      except Exception as e:
        panic("Verify threw an Exception despite not naturally throwing anything: " & e.msg)

  functions.transactions.verify = proc (
    hash: Hash[256]
  ) {.forceCheck: [].} =
    transactions[].verify(hash)

  functions.transactions.unverify = proc (
    hash: Hash[256]
  ) {.forceCheck: [].} =
    transactions[].unverify(hash)

  functions.transactions.beat = proc (
    hash: Hash[256]
  ) {.forceCheck: [].} =
    transactions[].beat(hash)

  functions.transactions.discoverTree = proc (
    hash: Hash[256]
  ): seq[Hash[256]] {.forceCheck: [].} =
    transactions[].discoverTree(hash)

  functions.transactions.discoverUnorderedTree = proc (
    hash: Hash[256],
    discovered: HashSet[Hash[256]]
  ): HashSet[Hash[256]] {.forceCheck: [].} =
    transactions[].discoverUnorderedTree(hash, discovered)

  functions.transactions.prune = proc (
    hash: Hash[256]
  ) {.forceCheck: [].} =
    transactions[].prune(hash)
