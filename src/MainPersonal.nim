include MainTransactions

proc mainPersonal() {.forceCheck: [].} =
    {.gcsafe.}:
        #Get the MinerWallet.
        functions.personal.getMinerWallet = proc (): MinerWallet {.inline, forceCheck: [].} =
            wallet.miner

        #Get the Wallet.
        functions.personal.getWallet = proc (): Wallet {.inline, forceCheck: [].} =
            wallet.wallet

        #Set the Wallet's Mnemonic.
        functions.personal.setMnemonic = proc (
            mnemonic: string,
            password: string
        ) {.forceCheck: [
            ValueError
        ].} =
            try:
                wallet.setWallet(mnemonic, password)
            except ValueError as e:
                raise e

        #Create a Send Transaction.
        functions.personal.send = proc (
            destination: string,
            amountStr: string
        ): Hash[256] {.forceCheck: [
            ValueError,
            NotEnoughMeros
        ].} =
            var
                #Wallet we're using.
                child: HDWallet
                #Spendable UTXOs.
                utxos: seq[FundedInput]
                #Amount in.
                amountIn: uint64
                #Amount out.
                amountOut: uint64
                #Send we'll end up creating.
                send: Send

            #Grab a child.
            try:
                child = wallet.wallet.external.next()
            except ValueError as e:
                doAssert(false, "Wallet has no usable keys: " & e.msg)
            utxos = transactions.getUTXOs(child.publicKey)
            try:
                amountOut = parseUInt(amountStr)
            except ValueError as e:
                raise e

            #Grab the needed UTXOs.
            try:
                var i: int = 0
                while i < utxos.len:
                    if transactions.loadSpenders(utxos[i]).len != 0:
                        utxos.delete(i)
                        continue

                    #Add this UTXO's amount to the amount in.
                    amountIn += transactions[utxos[i].hash].outputs[utxos[i].nonce].amount

                    #Remove uneeded UTXOs.
                    if amountIn >= amountOut:
                        if i + 1 < utxos.len:
                            utxos.delete(i + 1, utxos.len - 1)
                        break

                    #Increment i.
                    inc(i)
            except IndexError as e:
                doAssert(false, "Couldn't load a transaction we have an UTXO for: " & e.msg)

            #Make sure we have enough Meros.
            if amountIn < amountOut:
                raise newException(NotEnoughMeros, "Wallet didn't have enough money to create a Send.")

            #Create the outputs.
            var outputs: seq[SendOutput]
            try:
                outputs = @[
                    newSendOutput(
                        newEdPublicKey(cast[string](destination.getEncodedData())),
                        amountOut
                    )
                ]
            except ValueError as e:
                raise e

            #Add a change output.
            if amountIn != amountOut:
                outputs.add(
                    newSendOutput(
                        child.publicKey,
                        amountIn - amountOut
                    )
                )

            #Create the Send.
            send = newSend(
                utxos,
                outputs
            )

            #Sign the Send.
            child.sign(send)

            #Mine the Send.
            send.mine(functions.consensus.getSendDifficulty())

            #Add the Send.
            try:
                functions.transactions.addSend(send)
            except ValueError as e:
                doAssert(false, "Created a Send which was invalid: " & e.msg)
            except DataExists as e:
                doAssert(false, "Created a Send which already existed: " & e.msg)

            #Retun the hash.
            result = send.hash

    #Create a Data Transaction.
    functions.personal.data = proc (
        dataStr: string
    ): Hash[256] {.forceCheck: [
        ValueError,
        DataExists
    ].} =
        var
            #Wallet we're using.
            child: HDWallet
            #Data tip.
            tip: Hash[256]
            #Whether or not we need to create the intial data.
            initial: bool = false
            #Data.
            data: Data

        #Grab a child.
        try:
            child = wallet.wallet.external.next()
        except ValueError as e:
            doAssert(false, "Wallet has no usable keys: " & e.msg)

        try:
            tip = wallet.loadDataTip()
        except DataMissing:
            #Nim can't handle the following chain of events:
            #Spawning an awaited async task
            #From within a checked async task
            #From within an except Block.
            #Adding the initial Data from this except Block would trigger that chain of events.
            #That's why we use a flag.
            #For more info, see https://github.com/nim-lang/Nim/issues/13171.
            initial = true

        if initial:
            #Create the initial Data.
            try:
                data = newData(Hash[256](), child.publicKey.toString())
            except ValueError as e:
                doAssert(false, "Couldn't create the initial Data: " & e.msg)

            #Sign it.
            child.sign(data)

            #Mine it.
            data.mine(functions.consensus.getDataDifficulty())

            #Add it.
            try:
                functions.transactions.addData(data)
            except ValueError as e:
                doAssert(false, "Created a Data which was invalid: " & e.msg)
            except DataExists as e:
                raise e

            #Set the tip to the initial Data.
            tip = data.hash

        #Technically, the tip could be out of date.
        #We don't save the tip until after we publish it.
        var spenders: seq[Hash[256]] = newSeq[Hash[256]](1)
        while spenders.len != 0:
            spenders = functions.transactions.getSpenders(newInput(tip))
            if spenders.len != 0:
                tip = spenders[0]

        #Verify the tip exists.
        #It may not if we created a Data, saved the tip, rebooted without flushing the Transactions DB, and then tried to create a new Data.
        try:
            discard transactions[tip]
        except IndexError as e:
            raise newException(ValueError, "Creating a Data which competed with a previous Data thanks to missing Datas: " & e.msg)


        #Create the Data.
        try:
            data = newData(tip, dataStr)
        except ValueError as e:
            raise e

        #Sign the Data.
        child.sign(data)

        #Mine the Data.
        data.mine(functions.consensus.getDataDifficulty())

        #Add the Data.
        try:
            functions.transactions.addData(data)
        except ValueError as e:
            doAssert(false, "Created a Data which was invalid: " & e.msg)
        except DataExists as e:
            raise e

        #Save the new Data tip.
        wallet.saveDataTip(data.hash)

        #Return the hash.
        result = data.hash
