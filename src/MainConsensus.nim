include MainMerit

proc syncMeritRemovalTransactions(
  functions: GlobalFunctionBox,
  consensus: ref Consensus,
  network: Network,
  removal: MeritRemoval
): Future[void] {.forceCheck: [
  ValueError
], async.} =
  #Sync the MeritRemoval's transactions, if we don't have them already.
  proc syncMeritRemovalTransaction(
    hash: Hash[256]
  ): Future[void] {.forceCheck: [
    ValueError
  ], async.} =
    try:
      discard functions.transactions.getTransaction(hash)
    except IndexError:
      try:
        discard consensus[].getMeritRemovalTransaction(hash)
      except IndexError:
        try:
          consensus[].addMeritRemovalTransaction(await syncAwait network.syncManager.syncTransaction(hash))
        except DataMissing:
          raise newLoggedException(ValueError, "Couldn't find the Transaction behind a MeritRemoval.")
        except Exception as e:
          panic("Syncing a MeritRemoval's Transaction threw an Exception despite catching all thrown Exceptions: " & e.msg)

  try:
    case removal.element1:
      of Verification as verif:
        await syncMeritRemovalTransaction(verif.hash)
      of MeritRemovalVerificationPacket as packet:
        await syncMeritRemovalTransaction(packet.hash)
      else:
        discard

    case removal.element2:
      of Verification as verif:
        await syncMeritRemovalTransaction(verif.hash)
      of MeritRemovalVerificationPacket as packet:
        await syncMeritRemovalTransaction(packet.hash)
      else:
        discard
  except ValueError as e:
    raise e
  except Exception as e:
    panic("Syncing a MeritRemoval's Transactions threw an Exception despite catching all thrown Exceptions: " & e.msg)

proc mainConsensus(
  params: ChainParams,
  database: DB,
  functions: GlobalFunctionBox,
  merit: Merit,
  consensus: ref Consensus,
  transactions: ref Transactions,
  network: ref Network
) {.forceCheck: [].} =
  try:
    consensus[] = newConsensus(
      functions,
      database,
      merit.state,
      params.SEND_DIFFICULTY,
      params.DATA_DIFFICULTY
    )
  except ValueError:
    panic("Invalid initial Send/Data difficulty.")

  functions.consensus.getSendDifficulty = proc (): uint32 {.forceCheck: [].} =
    consensus.filters.send.difficulty
  functions.consensus.getDataDifficulty = proc (): uint32 {.forceCheck: [].} =
    consensus.filters.data.difficulty

  functions.consensus.isMalicious = proc (
    nick: uint16
  ): bool {.forceCheck: [].} =
    consensus.malicious.hasKey(nick)

  functions.consensus.getArchivedNonce = proc (
    holder: uint16
  ): int {.forceCheck: [].} =
    consensus[].getArchivedNonce(holder)

  #Returns true if the hash isn't recognized.
  functions.consensus.hasArchivedPacket = proc (
    hash: Hash[256]
  ): bool {.forceCheck: [].} =
    return not consensus.unmentioned.contains(hash)

  functions.consensus.getStatus = proc (
    hash: Hash[256]
  ): TransactionStatus {.forceCheck: [
    IndexError
  ].} =
    try:
      result = consensus[].getStatus(hash)
    except IndexError:
      raise newLoggedException(IndexError, "Couldn't find a Status for that hash.")

  functions.consensus.getThreshold = proc (
    epoch: int
  ): int {.forceCheck: [].} =
    merit.state.nodeThresholdAt(epoch)

  functions.consensus.getPending = proc (): tuple[
    packets: seq[VerificationPacket],
    elements: seq[BlockElement],
    aggregate: BLSSignature
  ] {.forceCheck: [].} =
    var pending: tuple[
      packets: seq[SignedVerificationPacket],
      elements: seq[BlockElement],
      aggregate: BLSSignature
    ] = consensus[].getPending()

    result = (cast[seq[VerificationPacket]](pending.packets), pending.elements, pending.aggregate)

  functions.consensus.addSignedVerification = proc (
    verif: SignedVerification
  ) {.forceCheck: [
    ValueError,
    DataExists
  ].} =
    logInfo "New Verification", holder = verif.holder, hash = verif.hash

    var mr: bool
    try:
      consensus[].add(merit.state, verif)
    #Invalid signature.
    except ValueError as e:
      raise e
    #Already added.
    except DataExists as e:
      raise e
    #MeritHolder committed a malicious act against the network.
    except MaliciousMeritHolder as e:
      #Flag the MeritRemoval.
      consensus[].flag(merit.blockchain, merit.state, cast[SignedMeritRemoval](e.removal))

      #Set mr to true.
      mr = true

    if mr:
      try:
        #Broadcast the first MeritRemoval.
        functions.network.broadcast(
          MessageType.SignedMeritRemoval,
          cast[SignedMeritRemoval](consensus.malicious[verif.holder][0]).signedSerialize()
        )
      except KeyError as e:
        panic("Couldn't get the MeritRemoval of someone who just had one created: " & e.msg)
      return

    logInfo "Added Verification", holder = verif.holder, hash = verif.hash

    #Broadcast the SignedVerification.
    functions.network.broadcast(
      MessageType.SignedVerification,
      verif.signedSerialize()
    )

  functions.consensus.addVerificationPacket = proc (
    packet: VerificationPacket
  ) {.forceCheck: [].} =
    logInfo "New Verification Packet from Block", hash = packet.hash, holders = packet.holders
    consensus[].add(merit.state, packet)
    logInfo "Added Verification Packet from Block", hash = packet.hash, holders = packet.holders

  functions.consensus.addSendDifficulty = proc (
    sendDiff: SendDifficulty
  ) {.forceCheck: [].} =
    logInfo "New Send Difficulty from Block", holder = sendDiff.holder, difficulty = sendDiff.difficulty
    consensus[].add(merit.state, sendDiff)
    logInfo "Added Send Difficulty from Block", holder = sendDiff.holder, difficulty = sendDiff.difficulty

  functions.consensus.addSignedSendDifficulty = proc (
    sendDiff: SignedSendDifficulty
  ) {.forceCheck: [
    ValueError,
    DataExists
  ].} =
    logInfo "New Send Difficulty", holder = sendDiff.holder, difficulty = sendDiff.difficulty

    var mr: bool
    try:
      consensus[].add(merit.state, sendDiff)
    except ValueError as e:
      raise e
    except DataExists as e:
      raise e
    except MaliciousMeritHolder as e:
      #Flag the MeritRemoval.
      consensus[].flag(merit.blockchain, merit.state, cast[SignedMeritRemoval](e.removal))

      #Set mr to true.
      mr = true

    if mr:
      try:
        #Broadcast the first MeritRemoval.
        functions.network.broadcast(
          MessageType.SignedMeritRemoval,
          cast[SignedMeritRemoval](consensus.malicious[sendDiff.holder][0]).signedSerialize()
        )
      except KeyError as e:
        panic("Couldn't get the MeritRemoval of someone who just had one created: " & e.msg)
      return

    logInfo "Added Send Difficulty", holder = sendDiff.holder, difficulty = sendDiff.difficulty

    #Broadcast the SendDifficulty.
    functions.network.broadcast(
      MessageType.SignedSendDifficulty,
      sendDiff.signedSerialize()
    )

  functions.consensus.addDataDifficulty = proc (
    dataDiff: DataDifficulty
  ) {.forceCheck: [].} =
    logInfo "New Data Difficulty from Block", holder = dataDiff.holder, difficulty = dataDiff.difficulty
    consensus[].add(merit.state, dataDiff)
    logInfo "Added Data Difficulty from Block", holder = dataDiff.holder, difficulty = dataDiff.difficulty

  functions.consensus.addSignedDataDifficulty = proc (
    dataDiff: SignedDataDifficulty
  ) {.forceCheck: [
    ValueError,
    DataExists
  ].} =
    logInfo "New Data Difficulty", holder = dataDiff.holder, difficulty = dataDiff.difficulty

    var mr: bool = false
    try:
      consensus[].add(merit.state, dataDiff)
    except ValueError as e:
      raise e
    except DataExists as e:
      raise e
    except MaliciousMeritHolder as e:
      #Flag the MeritRemoval.
      consensus[].flag(merit.blockchain, merit.state, cast[SignedMeritRemoval](e.removal))

      #Set mr to true.
      mr = true

    if mr:
      try:
        #Broadcast the first MeritRemoval.
        functions.network.broadcast(
          MessageType.SignedMeritRemoval,
          cast[SignedMeritRemoval](consensus.malicious[dataDiff.holder][0]).signedSerialize()
        )
      except KeyError as e:
        panic("Couldn't get the MeritRemoval of someone who just had one created: " & e.msg)
      return

    logInfo "Added Data Difficulty", holder = dataDiff.holder, difficulty = dataDiff.difficulty

    #Broadcast the DataDifficulty.
    functions.network.broadcast(
      MessageType.SignedDataDifficulty,
      dataDiff.signedSerialize()
    )

  functions.consensus.verifyUnsignedMeritRemoval = proc (
    mr: MeritRemoval
  ): Future[void] {.forceCheck: [
    ValueError,
    DataExists
  ], async.} =
    try:
      await syncMeritRemovalTransactions(functions, consensus, network[], mr)
    except ValueError as e:
      raise e
    except Exception as e:
      panic("Syncing a MeritRemoval's Transactions threw an Exception despite catching all thrown Exceptions: " & e.msg)

    try:
      consensus[].verify(mr, merit.state.holders)
    except ValueError as e:
      raise e
    except DataExists as e:
      #If it's cached, it's already been verified and it's not archived yet.
      if not consensus.malicious.hasKey(mr.holder):
        raise e

      try:
        for cachedMR in consensus.malicious[mr.holder]:
          if mr.reason == cachedMR.reason:
            return
      except KeyError:
        panic("Merit Holder confirmed to be in malicious doesn't have an entry in malicious.")
      raise e

  functions.consensus.addSignedMeritRemoval = proc (
    mr: SignedMeritRemoval
  ): Future[void] {.forceCheck: [
    ValueError,
    DataExists
  ], async.} =
    logInfo "New Merit Removal", holder = mr.holder, reason = mr.reason

    try:
      await syncMeritRemovalTransactions(functions, consensus, network[], mr)
    except ValueError as e:
      raise e
    except Exception as e:
      panic("Syncing a MeritRemoval's Transactions threw an Exception despite catching all thrown Exceptions: " & e.msg)

    try:
      consensus[].add(merit.blockchain, merit.state, mr)
    except ValueError as e:
      raise e
    except DataExists as e:
      raise e

    logInfo "Added Merit Removal", holder = mr.holder, reason = mr.reason

    #Broadcast the first MeritRemoval.
    try:
      functions.network.broadcast(
        MessageType.SignedMeritRemoval,
        cast[SignedMeritRemoval](consensus.malicious[mr.holder][0]).signedSerialize()
      )
    except KeyError as e:
      panic("Couldn't get the MeritRemoval of someone who just had one created: " & e.msg)
