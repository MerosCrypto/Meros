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

        #Add the Verification.
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
    #Create the Transactions.
    transactions[] = newTransactions(database, merit.blockchain)

    #Handle requests for an Transaction.
    functions.transactions.getTransaction = proc (
        hash: Hash[256]
    ): Transaction {.forceCheck: [
        IndexError
    ].} =
        try:
            result = transactions[][hash]
        except IndexError as e:
            raise e

    #Get a Transaction's spenders.
    functions.transactions.getSpenders = proc (
        input: Input
    ): seq[Hash[256]] {.forceCheck: [].} =
        transactions[].loadSpenders(input)

    #Handle Claims.
    functions.transactions.addClaim = proc (
        claim: Claim,
        syncing: bool = false
    ) {.forceCheck: [
        ValueError,
        DataExists
    ].} =
        #Print that we're adding the Claim.
        logInfo "New Claim", hash = claim.hash

        #Add the Claim.
        try:
            transactions[].add(claim, functions.merit.getPublicKey)
        #Passing a function which can raise IndexError raised one.
        except IndexError as e:
            panic("Passing a function which can raise an IndexError raised an IndexError: " & e.msg)
        #Invalid Claim.
        except ValueError as e:
            raise e
        #Data already exists.
        except DataExists as e:
            raise e

        #Register the Claim with Consensus.
        consensus[].register(merit.state, claim, merit.blockchain.height)

        logInfo "Added Claim", hash = claim.hash

        if not syncing:
            #Broadcast the Claim.
            functions.network.broadcast(
                MessageType.Claim,
                claim.serialize()
            )

            #Create a Verification.
            try:
                asyncCheck verify(wallet, functions, merit, consensus, claim)
            except Exception as e:
                panic("Verify threw an Exception despite not naturally throwing anything: " & e.msg)

    #Handle Sends.
    functions.transactions.addSend = proc (
        send: Send,
        syncing: bool = false
    ) {.forceCheck: [
        ValueError,
        DataExists
    ].} =
        #Print that we're adding the Send
        logInfo "New Send", hash = send.hash

        #Add the Send.
        try:
            transactions[].add(send)
        #Invalid Send.
        except ValueError as e:
            raise e
        #Data already exisrs.
        except DataExists as e:
            raise e

        #Register the Send with Consensus.
        consensus[].register(merit.state, send, merit.blockchain.height)

        logInfo "Added Send", hash = send.hash

        if not syncing:
            #Broadcast the Send.
            functions.network.broadcast(
                MessageType.Send,
                send.serialize()
            )

            #Create a Verification.
            try:
                asyncCheck verify(wallet, functions, merit, consensus, send)
            except Exception as e:
                panic("Verify threw an Exception despite not naturally throwing anything: " & e.msg)

    #Handle Datas.
    functions.transactions.addData = proc (
        data: Data,
        syncing: bool = false
    ) {.forceCheck: [
        ValueError,
        DataExists
    ].} =
        #Print that we're adding the Data
        logInfo "New Data", hash = data.hash

        #Add the Data.
        try:
            transactions[].add(data)
        #Invalid Data.
        except ValueError as e:
            raise e
        #Data already exisrs.
        except DataExists as e:
            raise e

        #Register the Data with Consensus.
        consensus[].register(merit.state, data, merit.blockchain.height)
        logInfo "Added Data", hash = data.hash

        if not syncing:
            #Broadcast the Data.
            functions.network.broadcast(
                MessageType.Data,
                data.serialize()
            )

            #Create a Verification.
            try:
                asyncCheck verify(wallet, functions, merit, consensus, data)
            except Exception as e:
                panic("Verify threw an Exception despite not naturally throwing anything: " & e.msg)

    #Mark a Transaction as verified.
    functions.transactions.verify = proc (
        hash: Hash[256]
    ) {.forceCheck: [].} =
        transactions[].verify(hash)

    #Mark a Transaction as unverified.
    functions.transactions.unverify = proc (
        hash: Hash[256]
    ) {.forceCheck: [].} =
        transactions[].unverify(hash)

    #Mark a Transaction as beaten.
    functions.transactions.beat = proc (
        hash: Hash[256]
    ) {.forceCheck: [].} =
        transactions[].beat(hash)

    #Discover a Transaction tree.
    functions.transactions.discoverTree = proc (
        hash: Hash[256]
    ): seq[Hash[256]] {.forceCheck: [].} =
        transactions[].discoverTree(hash)

    #Prune a Transaction from the Database.
    functions.transactions.prune = proc (
        hash: Hash[256]
    ) {.forceCheck: [].} =
        transactions[].prune(hash)

    #Get a key's UTXOs.
    functions.transactions.getUTXOs = proc (
        key: EdPublicKey
    ): seq[FundedInput] {.forceCheck: [].} =
        transactions[].getUTXOs(key)
