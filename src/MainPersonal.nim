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
    destination: string,
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
      amountIn: uint64
      amountOut: uint64
      send: Send

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
    var outputs: seq[SendOutput]
    try:
      outputs = @[
        newSendOutput(destination.getEncodedData(), amountOut)
      ]
    except ValueError as e:
      raise e

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
    ValueError,
    DataExists
  ], async.} =
    var
      #Wallet we're using.
      child: HDWallet
      #Data tip.
      tip: Hash[256]
      #Whether or not we need to create the intial data.
      initial: bool = false
      data: Data

    #Grab a child.
    try:
      child = wallet.wallet.external.next()
    except ValueError as e:
      panic("Wallet has no usable keys: " & e.msg)

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
        data = newData(Hash[256](), child.publicKey.serialize())
      except ValueError as e:
        panic("Couldn't create the initial Data: " & e.msg)

      child.sign(data)
      data.mine(functions.consensus.getDataDifficulty())

      try:
        await functions.transactions.addData(data)
      except ValueError as e:
        panic("Created a Data which was invalid: " & e.msg)
      except DataExists as e:
        raise e
      except Exception as e:
        panic("addData threw an Exception despite catching every Exception: " & e.msg)

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
      discard transactions[][tip]
    except IndexError as e:
      raise newLoggedException(ValueError, "Creating a Data which competed with a previous Data thanks to missing Datas: " & e.msg)

    try:
      data = newData(tip, dataStr)
    except ValueError as e:
      raise e

    child.sign(data)
    data.mine(functions.consensus.getDataDifficulty())

    #Add the Data.
    try:
      await functions.transactions.addData(data)
    except ValueError as e:
      panic("Created a Data which was invalid: " & e.msg)
    except DataExists as e:
      raise e
    except Exception as e:
      panic("addData threw an Exception despite catching every Exception: " & e.msg)

    #Save the new Data tip.
    wallet.saveDataTip(data.hash)

    result = data.hash
