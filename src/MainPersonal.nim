include MainTransactions

proc mainPersonal(
  wallet: WalletDB,
  functions: GlobalFunctionBox,
  transactions: ref Transactions
) {.forceCheck: [].} =
  functions.personal.getMinerWallet = proc (): MinerWallet {.forceCheck: [].} =
    wallet.miner

  functions.personal.getWallet = proc (): Wallet {.forceCheck: [].} =
    wallet.wallet

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

  functions.personal.send = proc (
    destinationArg: string,
    amountStr: string
  ): Future[Hash[256]] {.forceCheck: [
    ValueError,
    NotEnoughMeros
  ], async.} =
    var
      #Wallet we're using.
      child: HDWallet
      #Spendable UTXOs.
      utxos: seq[FundedInput]
      destination: Address
      amountIn: uint64
      amountOut: uint64
      send: Send

    try:
      destination = destinationArg.getEncodedData()
    except ValueError as e:
      raise e

    #Grab a child.
    try:
      child = wallet.wallet.external.next()
    except ValueError as e:
      panic("Wallet has no usable keys: " & e.msg)
    utxos = transactions[].getUTXOs(child.publicKey)
    try:
      amountOut = parseUInt(amountStr)
    except ValueError as e:
      raise e

    #Grab the needed UTXOs.
    try:
      var i: int = 0
      while i < utxos.len:
        if transactions[].loadSpenders(utxos[i]).len != 0:
          utxos.delete(i)
          continue

        #Add this UTXO's amount to the amount in.
        amountIn += transactions[][utxos[i].hash].outputs[utxos[i].nonce].amount

        #Remove uneeded UTXOs.
        if amountIn >= amountOut:
          if i + 1 < utxos.len:
            utxos.delete(i + 1, utxos.len - 1)
          break

        #Increment i.
        inc(i)
    except IndexError as e:
      panic("Couldn't load a transaction we have an UTXO for: " & e.msg)

    #Make sure we have enough Meros.
    if amountIn < amountOut:
      raise newLoggedException(NotEnoughMeros, "Wallet didn't have enough money to create a Send.")

    #Create the outputs.
    var outputs: seq[SendOutput] = @[
      newSendOutput(destination, amountOut)
    ]

    #Add a change output.
    if amountIn != amountOut:
      outputs.add(newSendOutput(child.publicKey, amountIn - amountOut))

    send = newSend(utxos, outputs)
    child.sign(send)
    send.mine(functions.consensus.getSendDifficulty())

    #Add the Send.
    try:
      await functions.transactions.addSend(send)
    except ValueError as e:
      panic("Created a Send which was invalid: " & e.msg)
    except DataExists as e:
      panic("Created a Send which already existed: " & e.msg)
    except Exception as e:
      panic("addSend threw an Exception despite catching every Exception: " & e.msg)

    result = send.hash

  functions.personal.data = proc (
    dataStr: string
  ): Future[Hash[256]] {.forceCheck: [
    ValueError
  ], async.} =
    #Wallet we're using.
    var child: HDWallet
    try:
      #Even though this call "next", this should always use the first Wallet.
      #Just a note since our BIP 44 usage will change in the future.
      child = wallet.wallet.external.next()
    except ValueError as e:
      panic("Wallet has no usable keys: " & e.msg)

    #Create the Data.
    try:
      wallet.stepData(dataStr, child, functions.consensus.getDataDifficulty())
    except ValueError as e:
      raise e

    #[
    We now need to add this Data.
    That said, we may need to add Datas before it if either:
    A) We didn't have an initial Data.
    B) We created a Data and then rebooted before the Transactions DB was saved to disk.
    Because of that, the following iterative approach is used to add all 'new' Datas.
    ]#
    var toAdd: seq[Data] = @[]
    for data in wallet.loadDatasFromTip():
      toAdd.add(data)

      #Reached the initial Data.
      if data.inputs[0].hash == Hash[256]():
        break
      #We have the Data it relies on.
      try:
        discard transactions[][data.inputs[0].hash]
        break
      except IndexError:
        discard

    for d in countdown(high(toAdd), 0):
      try:
        await functions.transactions.addData(toAdd[d])
      except ValueError as e:
        panic("Data from the WalletDB was invalid: " & e.msg)
      #Another async process, AKA the network, added it.
      #There is concern about a race condition where we create multiple Datas sharing an input.
      #Due to the synchronous outsourcing to the WalletDB, this is negated.
      except DataExists:
        continue
      except Exception as e:
        panic("addData threw an Exception despite catching every Exception: " & e.msg)

    result = toAdd[0].hash
