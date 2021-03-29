include MainTransactions

proc mainPersonal(
  db: WalletDB,
  functions: GlobalFunctionBox,
  transactions: ref Transactions
) {.forceCheck: [].} =
  functions.personal.getMinerWallet = proc (): MinerWallet {.forceCheck: [].} =
    db.miner

  functions.personal.getMnemonic = proc (): string {.forceCheck: [].} =
    db.getMnemonic()

  functions.personal.setWallet = proc (
    mnemonic: string,
    password: string
  ) {.forceCheck: [
    ValueError
  ].} =
    var wallet: InsecureWallet
    if mnemonic.len == 0:
      wallet = newWallet(password)
    else:
      try:
        wallet = newWallet(mnemonic, password)
      except ValueError as e:
        raise e

    var datas: seq[Data]
    block handleDatas:
      #Start with the initial data, discovering spenders until the tip.
      var initial: Data
      try:
        initial = newData(Hash[256](), wallet.hd[0].derive(1).first().publicKey.serialize())
      except ValueError as e:
        panic("Couldn't create an initial Data to discover a Data tip: " & e.msg)
      try:
        discard transactions[][initial.hash]
      #No Datas.
      except IndexError:
        break handleDatas

      var
        last: Hash[256] = initial.hash
        spenders: seq[Hash[256]] = transactions[].loadSpenders(newInput(last))
      while spenders.len != 0:
        last = spenders[0]
        spenders = transactions[].loadSpenders(newInput(last))

      #Grab the chain.
      try:
        datas = @[cast[Data](transactions[][last])]
        while datas[^1].inputs[0].hash != Hash[256]():
          datas.add(cast[Data](transactions[][datas[^1].inputs[0].hash]))
      except IndexError as e:
        panic("Couldn't get a Data chain from a discovered tip: " & e.msg)

    try:
      db.setWallet(wallet, datas)
    except ValueError as e:
      raise e

  functions.personal.getAccountKey = proc (): EdPublicKey {.forceCheck: [].} =
    db.accountZero

  functions.personal.getAddress = proc (
    index: Option[uint32]
  ): string {.gcsafe, forceCheck: [
    ValueError
  ].} =
    try:
      result = db.getAddress(
        index,
        proc (
          key: EdPublicKey
        ): bool {.gcsafe, forceCheck: [].} =
          transactions[].loadIfKeyWasUsed(key)
      )
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
      child: HDWallet = db.wallet.external.first()
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

    #Grab the UTXOs.
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
    dataStr: string,
    password: string
  ): Future[Hash[256]] {.forceCheck: [
    ValueError
  ], async.} =
    #Create the Data.
    try:
      db.stepData(password, dataStr, functions.consensus.getDataDifficulty())
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
    for data in db.loadDatasFromTip():
      toAdd.add(data)

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
