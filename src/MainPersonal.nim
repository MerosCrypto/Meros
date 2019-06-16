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
            NotEnoughMeros
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
                for i in 0 ..< utxos.len:
                    amountIn += transactions[utxos[i].hash].outputs[utxos[i].nonce].amount
                    if amountIn >= amountOut:
                        utxos.delete(i + 1, utxos.len)
                        break
            except IndexError as e:
                doAssert(false, "Couldn't load a transaction we have an UTXO for: " & e.msg)

            #Make sure we have enough Meros.
            if amountIn < amountOut:
                raise newException(NotEnoughMeros, "Wallet didn't have enough money to create a Send.")

            #Create the Send.
            var send: Send
            try:
                send = newSend(
                    utxos,
                    newSendOutput(
                        newEdPublicKey(destination.toPublicKey()),
                        amountOut
                    ),
                    newSendOutput(
                        wallet.publicKey,
                        amountIn - amountOut
                    )
                )
            except ValueError as e:
                raise newException(AddressError, e.msg)
            except AddressError as e:
                fcRaise e
            except EdPublicKeyError as e:
                raise newException(AddressError, e.msg)

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
                doAssert(false, "Created a Send which already existed: " & e.msg)

            #Retun the hash.
            result = send.hash

    discard """
    #Create a Data Transaction.
    functions.personal.data = proc (
        data: string
    ) {.forceCheck: [
        NotEnoughMeros
    ].} =
        #Create the Data.
        var data: Data = newData(
            data
        )

        #Sign the Data.
        wallet.sign(data)

        #Mine the Send.
        data.mine(transactions.difficulties.data)

        #Add the Send.
        try:
            functions.transactions.addData(data)
        except ValueError as e:
            doAssert(false, "Created a Send which was invalid: " & e.msg)
        except DataExists as e:
            doAssert(false, "Created a Send which already existed: " & e.msg)
    """
