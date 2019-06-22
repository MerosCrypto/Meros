include MainTransactions

proc mainPersonal() {.forceCheck: [].} =
    {.gcsafe.}:
        #Get the Wallet.
        functions.personal.getWallet = proc (): Wallet {.inline, forceCheck: [].} =
            wallet

        #Set the Wallet's secret.
        functions.personal.setSecret = proc (
            secret: string
        ) {.forceCheck: [
            ValueError,
            RandomError
        ].} =
            if secret.len == 0:
                try:
                    wallet = newHDWallet()
                except ValueError as e:
                    fcRaise e
                except RandomError as e:
                    fcRaise e
            else:
                try:
                    wallet = newHDWallet(secret)
                except ValueError as e:
                    fcRaise e

        #Create a Send Transaction.
        functions.personal.send = proc (
            destination: string,
            amountStr: string
        ): Hash[384] {.forceCheck: [
            ValueError,
            AddressError,
            NotEnoughMeros,
            DataExists
        ].} =
            var
                #Spendable UTXOs.
                utxos: seq[SendInput] = transactions.getUTXOs(wallet.publicKey)
                #Amount in.
                amountIn: uint64
                #Amount out.
                amountOut: uint64
            try:
                amountOut = parseUInt(amountStr)
            except ValueError as e:
                fcRaise e

            #Grab the needed UTXOs.
            try:
                var i: int = 0
                while i < utxos.len:
                    #Skip UTXOs that are spent but only spent in pending TXs.
                    #Pending is defined as TXs with one verification; not anything created and broadcasted.
                    if transactions.spent.hasKey(utxos[i].toString(Send)):
                        utxos.delete(i)
                        continue

                    #Add this UTXO's amount to the amount in.
                    amountIn += transactions[utxos[i].hash].outputs[utxos[i].nonce].amount

                    #Remove uneeded UTXOs.
                    if amountIn >= amountOut:
                        if i + 1 < utxos.len:
                            utxos.delete(i + 1, utxos.len - 1)
                        break
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
                        newEdPublicKey(destination.toPublicKey()),
                        amountOut
                    )
                ]
            except EdPublicKeyError as e:
                raise newException(AddressError, e.msg)
            except AddressError as e:
                fcRaise e

            #Add a change output.
            if amountIn != amountOut:
                outputs.add(
                    newSendOutput(
                        wallet.publicKey,
                        amountIn - amountOut
                    )
                )

            #Create the Send.
            var send: Send
            try:
                send = newSend(
                    utxos,
                    outputs
                )
            except ValueError as e:
                raise newException(ValueError, e.msg)

            #Sign the Send.
            wallet.sign(send)

            #Mine the Send.
            try:
                send.mine(transactions.difficulties.send)
            except ArgonError as e:
                doAssert(false, "Couldn't mine a Send: " & e.msg)

            #Add the Send.
            try:
                functions.transactions.addSend(send)
            except ValueError as e:
                doAssert(false, "Created a Send which was invalid: " & e.msg)
            except DataExists as e:
                fcRaise e

            #Retun the hash.
            result = send.hash

    #Create a Data Transaction.
    functions.personal.data = proc (
        dataStr: string
    ): Hash[384] {.forceCheck: [
        ValueError,
        DataExists
    ].} =
        #Create the Data.
        var data: Data
        try:
            try:
                data = newData(
                    transactions.loadData(wallet.publicKey),
                    dataStr
                )
            except DBReadError:
                data = newData(
                    wallet.publicKey,
                    dataStr
                )
        except ValueError as e:
            fcRaise e

        #Sign the Data.
        wallet.sign(data)

        #Mine the Data.
        try:
            data.mine(transactions.difficulties.data)
        except ArgonError as e:
            doAssert(false, "Couldn't mine a Data: " & e.msg)

        #Add the Data.
        try:
            functions.transactions.addData(data)
        except ValueError as e:
            doAssert(false, "Created a Data which was invalid: " & e.msg)
        except DataExists as e:
            fcRaise e

        #Retun the hash.
        result = data.hash
