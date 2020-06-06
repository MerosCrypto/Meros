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
  if wallet.miner.initiated and (merit.state[wallet.miner.nick, status.epoch] > 0):
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
      functions.consensus.addSignedVerification(verif)
    except ValueError as e:
      panic("Created a Verification with an invalid signature: " & e.msg)
    except DataExists as e:
      panic("Created a Verification which already exists: " & e.msg)

proc mainTransactions(
  database: DB,
  wallet: WalletDB,
  functions: GlobalFunctionBox,
  merit: Merit,
  consensus: ref Consensus,
  transactions: ref Transactions
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

  functions.transactions.getSpenders = proc (
    input: Input
  ): seq[Hash[256]] {.forceCheck: [].} =
    transactions[].loadSpenders(input)

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
      functions.network.broadcast(
        MessageType.Claim,
        claim.serialize()
      )

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
  ].} =
    logInfo "New Send", hash = send.hash

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
    syncing: bool = false,
    stillVerify: bool = false
  ) {.forceCheck: [
    ValueError,
    DataExists
  ].} =
    logInfo "New Data", hash = data.hash

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

    if (not syncing) or (syncing and stillVerify):
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

  functions.transactions.prune = proc (
    hash: Hash[256]
  ) {.forceCheck: [].} =
    transactions[].prune(hash)

  functions.transactions.getUTXOs = proc (
    key: EdPublicKey
  ): seq[FundedInput] {.forceCheck: [].} =
    transactions[].getUTXOs(key)
