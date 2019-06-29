include MainMerit

#Creates and publishes a Verification.
proc verify(
    transaction: Transaction
) {.forceCheck: [], async.} =
    #Make sure we're a Miner with Merit.
    if config.miner.initiated and (merit.state[config.miner.publicKey] > 0):
        #Acquire the verify lock.
        while not tryAcquire(verifyLock):
            #While we can't acquire it, allow other async processes to run.
            try:
                await sleepAsync(1)
            except Exception as e:
                doAssert(false, "Couldn't sleep for 0.001 seconds after failing to acqure the lock: " & e.msg)

        #Make sure we didn't already verify a Transaction which spends the same inputs.
        #This must absolutely be single-threaded/non-async.
        #We only mark a TX as spent when the spoending TX has one Verification.
        #If we check, then let other code run, then verify...
        if not transactions.isFirst(transaction):
            return

        #Verify the Transaction.
        var verif: SignedVerification = newSignedVerificationObj(transaction.hash)
        try:
            config.miner.sign(verif, consensus[config.miner.publicKey].height)
        except BLSError as e:
            doAssert(false, "Couldn't create a SignedVerification due to a BLSError: " & e.msg)

        #Add the verif to consensus.
        try:
            consensus.add(verif, true)
        except ValueError as e:
            doAssert(false, "Created a SignedVerification with an invalid signature: " & e.msg)
        except GapError as e:
            doAssert(false, "Created a SignedVerification with an invalid nonce: " & e.msg)
        except BLSError as e:
            doAssert(false, "Couldn't add a SignedVerification due to a BLSError: " & e.msg)
        except MaliciousMeritHolder as e:
            doAssert(false, "Created a SignedVerification which causes a Merit Removal: " & e.msg)
        except DataExists as e:
            doAssert(false, "Created a SignedVerification already added to the Consensus DAG: " & e.msg)

        #Release the verify lock.
        release(verifyLock)

        #Add the Verification to the Transactions.
        try:
            transactions.verify(verif, merit.state[verif.holder], merit.state.live)
        except ValueError as e:
            doAssert(false, "Tried verifying a non-existant (in the cache) Transaction: " & e.msg)

        #Broadcast the Verification.
        functions.network.broadcast(
            MessageType.SignedVerification,
            verif.serialize()
        )

proc mainTransactions() {.forceCheck: [].} =
    {.gcsafe.}:
        #Create the Transactions.
        transactions = newTransactions(
            database,
            consensus,
            merit,
            SEND_DIFFICULTY,
            DATA_DIFFICULTY
        )

        #Handle requests for the Difficulties.
        functions.transactions.getDifficulties = proc (): Difficulties {.forceCheck: [].} =
            transactions.difficulties

        #Handle requests for an Transaction.
        functions.transactions.getTransaction = proc (
            hash: Hash[384]
        ): Transaction {.forceCheck: [
            IndexError
        ].} =
            try:
                result = transactions[hash]
            except IndexError as e:
                fcRaise e

        #Handle Claims.
        functions.transactions.addClaim = proc (
            claim: Claim,
            syncing: bool = false
        ) {.forceCheck: [
            ValueError,
            DataExists
        ].} =
            #Print that we're adding the Claim.
            echo "Adding a new Claim."

            #Add the Claim.
            try:
                transactions.add(claim)
            #Invalid Claim.
            except ValueError as e:
                fcRaise e
            #Data already exisrs.
            except DataExists as e:
                fcRaise e

            echo "Successfully added the Claim."

            if not syncing:
                #Broadcast the Claim.
                functions.network.broadcast(
                    MessageType.Claim,
                    claim.serialize()
                )

                #Create a Verification.
                try:
                    asyncCheck verify(claim)
                except Exception as e:
                    doAssert(false, "Verify threw an Exception despite not naturally throwing anything: " & e.msg)

        #Handle Sends.
        functions.transactions.addSend = proc (
            send: Send,
            syncing: bool = false
        ) {.forceCheck: [
            ValueError,
            DataExists
        ].} =
            #Print that we're adding the Send.
            echo "Adding a new Send."

            #Add the Send.
            try:
                transactions.add(send)
            #Invalid Send.
            except ValueError as e:
                fcRaise e
            #Data already exisrs.
            except DataExists as e:
                fcRaise e

            echo "Successfully added the Send."

            if not syncing:
                #Broadcast the Send.
                functions.network.broadcast(
                    MessageType.Send,
                    send.serialize()
                )

                #Create a Verification.
                try:
                    asyncCheck verify(send)
                except Exception as e:
                    doAssert(false, "Verify threw an Exception despite not naturally throwing anything: " & e.msg)

        #Handle Datas.
        functions.transactions.addData = proc (
            data: Data,
            syncing: bool = false
        ) {.forceCheck: [
            ValueError,
            DataExists
        ].} =
            #Print that we're adding the Data.
            echo "Adding a new Data."

            #Add the Data.
            try:
                transactions.add(data)
            #Invalid Data.
            except ValueError as e:
                fcRaise e
            #Data already exisrs.
            except DataExists as e:
                fcRaise e

            echo "Successfully added the Data."

            if not syncing:
                #Broadcast the Data.
                functions.network.broadcast(
                    MessageType.Data,
                    data.serialize()
                )

                #Create a Verification.
                try:
                    asyncCheck verify(data)
                except Exception as e:
                    doAssert(false, "Verify threw an Exception despite not naturally throwing anything: " & e.msg)
