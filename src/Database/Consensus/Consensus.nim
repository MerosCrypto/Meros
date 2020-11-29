import sequtils, sets, tables

import ../../lib/[Errors, Hash]
import ../../Wallet/MinerWallet

import ../../objects/GlobalFunctionBoxObj

import ../Transactions/Transactions

import ../Merit/objects/[BlockObj, BlockchainObj, EpochsObj]
import ../Merit/State

import objects/SpamFilterObj
export SpamFilterObj

import Elements/Elements
export Elements

import TransactionStatus as TransactionStatusFile
export TransactionStatusFile

import ../Filesystem/DB/ConsensusDB

import objects/ConsensusObj
export ConsensusObj

import ../../Network/Serialize/Consensus/[
  SerializeElement,
  SerializeVerification,
  SerializeSendDifficulty,
  SerializeDataDifficulty
]

proc newConsensus*(
  functions: GlobalFunctionBox,
  db: DB,
  state: State,
  sendDiff: uint32,
  dataDiff: uint32
): Consensus {.inline, forceCheck: [].} =
  newConsensusObj(functions, db, state, sendDiff, dataDiff)

#Flag a MeritHolder as malicious.
proc flag*(
  consensus: var Consensus,
  blockchain: Blockchain,
  state: State,
  holder: uint16
) {.forceCheck: [].} =
  #Reclaulcate the affected Transactions in Epochs.
  var
    status: TransactionStatus
    blockInEpochs: Block
  for b in max(blockchain.height - 5, 0) ..< blockchain.height:
    try:
      blockInEpochs = blockchain[b]
    except IndexError as e:
      panic("Couldn't get a Block from the Blockchain despite iterating up to the height: " & e.msg)

    for packet in blockInEpochs.body.packets:
      try:
        status = consensus.getStatus(packet.hash)
      except IndexError as e:
        panic("Couldn't get the status of a Transaction in Epochs at one point: " & e.msg)

      #Don't recalculate Transactions which have already finalized.
      if status.merit != -1:
        continue

      if status.verified and status.holders.contains(holder):
        var merit: int = 0
        for holder in status.holders:
          if not consensus.malicious.hasKey(holder):
            merit += state[holder, status.epoch]

        if merit < state.nodeThresholdAt(status.epoch):
          consensus.unverify(packet.hash, status)

  #Recalculate the affected Transactions not yet in Epochs.
  for hash in consensus.unmentioned:
    try:
      status = consensus.getStatus(hash)
    except IndexError as e:
      panic("Couldn't get the status of a Transaction yet to be mentioned in Epochs: " & e.msg)

    if status.verified and status.holders.contains(holder):
      var merit: int = 0
      for holder in status.holders:
        if not consensus.malicious.hasKey(holder):
          merit += state[holder, status.epoch]

      if merit < state.nodeThresholdAt(status.epoch):
        consensus.unverify(hash, status)

#Get a holder's nonce.
#Used to verify Blocks in NetworkSync.
proc getArchivedNonce*(
  consensus: Consensus,
  holder: uint16
): int {.forceCheck: [].} =
  try:
    result = consensus.archived[holder]
  except KeyError:
    #This causes Blocks with invalid holders to get rejected for having an invalid nonce.
    #We shouldn't need it due to other checks, but this removes the necessity to add try/catches to the entire chain.
    result = -2

#Register a Transaction.
proc register*(
  consensus: var Consensus,
  state: State,
  tx: Transaction,
  height: int
) {.forceCheck: [].} =
  #Create the status.
  var status: TransactionStatus = newTransactionStatusObj(tx.hash, height + 6)

  if not (
    (tx of Claim) or
    (
      (tx of Data) and
      (cast[Data](tx).isFirstData or (tx.inputs[0].hash == consensus.genesis))
    )
  ):
    for input in tx.inputs:
      #Check for competing Transactions.
      var spenders: seq[Hash[256]] = consensus.functions.transactions.getSpenders(input)
      if (spenders.len != 1) and (input.hash != Hash[256]()):
        status.competing = true

        #If there's a competing Transaction, mark competitors as needing to default.
        #This will run for every input with multiple spenders.
        if status.competing:
          for spender in spenders:
            if spender == tx.hash:
              continue

            try:
              consensus.getStatus(spender).competing = true
            except IndexError:
              panic("Competing Transaction doesn't have a Status despite being marked as a spender.")

  #Set the status.
  consensus.setStatus(tx.hash, status)

  #Mark the Transaction as unmentioned.
  consensus.setUnmentioned(tx.hash)

#Check if a Verification for a Transaction causes a MeritRemoval.
proc checkMaliciousVerification*(
  consensus: Consensus,
  holder: uint16,
  txHash: Hash[256]
): tuple[malicious: bool, other: TransactionStatus] {.forceCheck: [].} =
  var tx: Transaction
  try:
    tx = consensus.functions.transactions.getTransaction(txHash)
  except IndexError as e:
    panic("Couldn't get the Transaction behind a Verification: " & e.msg)

  #Initial/Block Datas.
  if (
    (tx of Data) and
    (
      (tx.inputs[0].hash == consensus.genesis) or
      (tx.inputs[0].hash == Hash[256]())
    )
  ):
    return

  for input in tx.inputs:
    var spenders: seq[Hash[256]] = consensus.functions.transactions.getSpenders(input)
    for spender in spenders:
      if spender == txHash:
        continue

      #Get the spender's status.
      var status: TransactionStatus
      try:
        status = consensus.getStatus(spender)
      except IndexError as e:
        panic("Couldn't get the status of a Transaction: " & e.msg)

      if status.holders.contains(holder):
        return (true, status)

#Add a VerificationPacket.
proc add*(
  consensus: var Consensus,
  state: State,
  packet: VerificationPacket
) {.forceCheck: [].} =
  var status: TransactionStatus
  #Get the status.
  try:
    status = consensus.getStatus(packet.hash)
  #If there's no TX status, the TX wasn't registered.
  except IndexError:
    panic("Adding a VerificationPacket for a non-existent Transaction.")

  #Add the packet.
  status.add(packet)
  #Calculate Merit.
  consensus.calculateMerit(state, packet.hash, status)
  #Set the status.
  consensus.setStatus(packet.hash, status)

#Add a SignedVerification.
proc add*(
  consensus: var Consensus,
  state: State,
  verif: SignedVerification
) {.forceCheck: [
  ValueError,
  DataMissing,
  DataExists,
  MaliciousMeritHolder
].} =
  #[
  This can be triggered if one node is a block behind the other.
  A ValueError would cause a disconnection. A DataMissing is accurate and forgiving.
  That said, DataMissing has side effects; it attempts to sync the underlying TX.
  If it's found, and this is still missing, a panic happens.
  DataExists is similar and forgiving, without this side effect.

  This function has a similar raise below when it checks if the TX in question was beaten.
  ]#
  if not state.isValidHolderWithMerit(verif.holder):
    raise newLoggedException(DataExists, "Sent Verification with an invalid holder/holder without Merit.")

  #Verify the signature.
  try:
    if not verif.signature.verify(
      newBLSAggregationInfo(
        state.holders[verif.holder],
        verif.serializeWithoutHolder()
      )
    ):
      raise newLoggedException(ValueError, "Invalid SignedVerification signature.")
  except BLSError:
    panic("Holder with an infinite key entered the system.")

  #Get the Transaction.
  var tx: Transaction
  try:
    tx = consensus.functions.transactions.getTransaction(verif.hash)
  except IndexError:
    raise newLoggedException(DataMissing, "Unknown Verification.")

  #Get the status.
  var status: TransactionStatus
  try:
    status = consensus.getStatus(verif.hash)
  except IndexError:
    panic("SignedVerification added for a Transaction which was not registered.")

  #Add the Verification.
  try:
    status.add(verif)
  except DataExists as e:
    raise e

  #Check if the Verification is malicious.
  var potentialRemoval: tuple[
    malicious: bool,
    other: TransactionStatus
  ] = consensus.checkMaliciousVerification(verif.holder, verif.hash)
  if potentialRemoval.malicious:
    try:
      var partial: bool = not potentialRemoval.other.signatures.hasKey(verif.holder)
      raise newMaliciousMeritHolder(
        "Verifier verified competing Transactions.",
        newSignedMeritRemoval(
          verif.holder,
          partial,
          newVerificationObj(potentialRemoval.other.packet.hash),
          verif,
          if partial:
            verif.signature
          else:
            @[potentialRemoval.other.signatures[verif.holder], verif.signature].aggregate()
        )
      )
    except KeyError as e:
      panic("Couldn't get a holder's unarchived Verification signature: " & e.msg)

  #Make sure the Transaction isn't beaten.
  if status.beaten:
    #DataExists to not cause a disconnect due to one node needing to catch up.
    #Same reasoning as the above.
    raise newLoggedException(DataExists, "Verification is for a beaten Transaction.")

  #Calculate Merit.
  consensus.calculateMerit(state, verif.hash, status)
  #Set the status.
  consensus.setStatus(verif.hash, status)

#Add a SendDifficulty.
proc add*(
  consensus: var Consensus,
  state: State,
  sendDiff: SendDifficulty
) {.forceCheck: [].} =
  consensus.db.save(sendDiff)
  consensus.filters.send.update(state, sendDiff.holder, sendDiff.difficulty)

#Add a SignedSendDifficulty.
proc add*(
  consensus: var Consensus,
  state: State,
  sendDiff: SignedSendDifficulty
) {.forceCheck: [
  ValueError,
  DataExists,
  MaliciousMeritHolder
].} =
  if not state.isValidHolderWithMerit(sendDiff.holder):
    return

  #Verify the SendDifficulty's signature.
  try:
    if not sendDiff.signature.verify(
      newBLSAggregationInfo(
        state.holders[sendDiff.holder],
        sendDiff.serializeWithoutHolder()
      )
    ):
      raise newLoggedException(ValueError, "Invalid SendDifficulty signature.")
  except BLSError:
    raise newLoggedException(ValueError, "Invalid SendDifficulty signature.")

  #Verify the nonce. This is done in NetworkSync for non-signed versions.
  if sendDiff.nonce > consensus.db.load(sendDiff.holder) + 1:
    raise newLoggedException(ValueError, "SendDifficulty skips a nonce.")

  if sendDiff.nonce <= consensus.db.load(sendDiff.holder):
    #If this isn't the existing Element, it's cause for a MeritRemoval.
    var other: BlockElement
    try:
      other = consensus.db.load(sendDiff.holder, sendDiff.nonce)
    except DBReadError as e:
      panic("Couldn't read a Block Element with a nonce lower than the holder's current nonce: " & e.msg)

    if other == sendDiff:
      raise newLoggedException(DataExists, "Already added this SendDifficulty.")

    try:
      var partial: bool = sendDiff.nonce <= consensus.archived[sendDiff.holder]
      raise newMaliciousMeritHolder(
        "SendDifficulty shares a nonce with a different Element.",
        newSignedMeritRemoval(
          sendDiff.holder,
          partial,
          other,
          sendDiff,
          if partial:
            sendDiff.signature
          else:
            @[
              consensus.signatures[sendDiff.holder][sendDiff.nonce - consensus.archived[sendDiff.holder] - 1],
              sendDiff.signature
            ].aggregate()
        )
      )
    except KeyError as e:
      panic("Either couldn't get a holder's archived nonce or one of their signatures: " & e.msg)

  #Add the SendDifficulty.
  consensus.add(state, cast[SendDifficulty](sendDiff))

  #Save the signature.
  try:
    consensus.signatures[sendDiff.holder].add(sendDiff.signature)
    consensus.db.saveSignature(sendDiff.holder, sendDiff.nonce, sendDiff.signature)
  except KeyError as e:
    panic("Couldn't cache a signature: " & e.msg)

#Add a DataDifficulty.
proc add*(
  consensus: var Consensus,
  state: State,
  dataDiff: DataDifficulty
) {.forceCheck: [].} =
  consensus.db.save(dataDiff)
  consensus.filters.data.update(state, dataDiff.holder, dataDiff.difficulty)

#Add a SignedDataDifficulty.
proc add*(
  consensus: var Consensus,
  state: State,
  dataDiff: SignedDataDifficulty
) {.forceCheck: [
  ValueError,
  DataExists,
  MaliciousMeritHolder
].} =
  if not state.isValidHolderWithMerit(dataDiff.holder):
    return

  #Verify the DataDifficulty's signature.
  try:
    if not dataDiff.signature.verify(
      newBLSAggregationInfo(
        state.holders[dataDiff.holder],
        dataDiff.serializeWithoutHolder()
      )
    ):
      raise newLoggedException(ValueError, "Invalid DataDifficulty signature.")
  except BLSError:
    raise newLoggedException(ValueError, "Invalid DataDifficulty signature.")

  #Verify the nonce. This is done in NetworkSync for non-signed versions.
  if dataDiff.nonce > consensus.db.load(dataDiff.holder) + 1:
    raise newLoggedException(ValueError, "DataDifficulty skips a nonce.")

  if dataDiff.nonce <= consensus.db.load(dataDiff.holder):
    #If this isn't the existing Element, it's cause for a MeritRemoval.
    var other: BlockElement
    try:
      other = consensus.db.load(dataDiff.holder, dataDiff.nonce)
    except DBReadError as e:
      panic("Couldn't read a Block Element with a nonce lower than the holder's current nonce: " & e.msg)

    if other == dataDiff:
      raise newLoggedException(DataExists, "Already added this DataDifficulty.")

    try:
      var partial: bool = dataDiff.nonce <= consensus.archived[dataDiff.holder]
      raise newMaliciousMeritHolder(
        "DataDifficulty shares a nonce with a different Element.",
        newSignedMeritRemoval(
          dataDiff.holder,
          partial,
          other,
          dataDiff,
          if partial:
            dataDiff.signature
          else:
            @[
              consensus.signatures[dataDiff.holder][dataDiff.nonce - consensus.archived[dataDiff.holder] - 1],
              dataDiff.signature
            ].aggregate()
        )
      )
    except KeyError as e:
      panic("Either couldn't get a holder's archived nonce or one of their signatures: " & e.msg)

  #Add the DataDifficulty.
  consensus.add(state, cast[DataDifficulty](dataDiff))

  #Save the signature.
  try:
    consensus.signatures[dataDiff.holder].add(dataDiff.signature)
    consensus.db.saveSignature(dataDiff.holder, dataDiff.nonce, dataDiff.signature)
  except KeyError as e:
    panic("Couldn't cache a signature: " & e.msg)

#Verify a MeritRemoval's validity.
proc verify(
  consensus: Consensus,
  mr: SignedMeritRemoval
) {.forceCheck: [
  ValueError,
  DataExists
].} =
  proc checkSecondCompeting(
    hash: Hash[256]
  ) {.forceCheck: [
    ValueError
  ].} =
    if mr.partial:
      var status: TransactionStatus
      try:
        status = consensus.db.load(hash)
      except DBReadError:
        raise newLoggedException(ValueError, "Unknown hash.")

      if (not status.holders.contains(mr.holder)) or status.signatures.hasKey(mr.holder):
        raise newLoggedException(ValueError, "Verification isn't archived.")

    var
      inputs: HashSet[string] = initHashSet[string]()
      tx: Transaction
    try:
      tx = consensus.functions.transactions.getTransaction(hash)
    except IndexError:
      try:
        tx = consensus.getMeritRemovalTransaction(hash)
      except IndexError:
        raise newLoggedException(ValueError, "Unknown Transaction verified in first Element.")

    for input in tx.inputs:
      inputs.incl(input)

    var secondHash: Hash[256]
    case mr.element2:
      of Verification as verif:
        secondHash = verif.hash
      else:
        raise newLoggedException(ValueError, "Invalid second Element.")

    if hash == secondHash:
      raise newLoggedException(ValueError, "MeritRemoval claims a Transaction competes with itself.")

    try:
      tx = consensus.functions.transactions.getTransaction(secondHash)
    except IndexError:
      try:
        tx = consensus.getMeritRemovalTransaction(hash)
      except IndexError:
        raise newLoggedException(ValueError, "Unknown Transaction verified in second Element.")

    for input in tx.inputs:
      if inputs.contains(input):
        return
    raise newLoggedException(ValueError, "Transactions don't compete.")

  proc checkSecondSameNonce(
    nonce: int
  ) {.forceCheck: [
    ValueError
  ].} =
    try:
      if mr.partial and ((nonce > consensus.archived[mr.holder]) or (mr.element1 != consensus.db.load(mr.holder, nonce))):
        raise newLoggedException(ValueError, "First Element isn't archived.")
    except KeyError:
      raise newLoggedException(ValueError, "MeritRemoval has an invalid holder.")
    except DBReadError as e:
      panic("Nonce was within bounds yet no Element could be loaded: " & e.msg)

    case mr.element2:
      of Verification as _:
        raise newLoggedException(ValueError, "Invalid second Element.")
      of SendDifficulty as sd:
        if nonce != sd.nonce:
          raise newLoggedException(ValueError, "Second Element has a distinct nonce.")

        if (
          (mr.element1 of SendDifficulty) and
          (cast[SendDifficulty](mr.element1).difficulty == sd.difficulty)
        ):
          raise newLoggedException(ValueError, "Elements are the same.")
      of DataDifficulty as dd:
        if nonce != dd.nonce:
          raise newLoggedException(ValueError, "Second Element has a distinct nonce.")

        if (
          (mr.element1 of DataDifficulty) and
          (cast[DataDifficulty](mr.element1).difficulty == dd.difficulty)
        ):
          raise newLoggedException(ValueError, "Elements are the same.")
      else:
        panic("Unsupported MeritRemoval Element.")

  try:
    case mr.element1:
      of Verification as verif:
        checkSecondCompeting(verif.hash)
      of SendDifficulty as sd:
        checkSecondSameNonce(sd.nonce)
      of DataDifficulty as dd:
        checkSecondSameNonce(dd.nonce)
      else:
        panic("Unsupported MeritRemoval Element.")
  except ValueError as e:
    raise e

#Add a SignedMeritRemoval.
proc add*(
  consensus: var Consensus,
  blockchain: Blockchain,
  state: State,
  mr: SignedMeritRemoval
) {.forceCheck: [
  ValueError,
  DataExists
].} =
  #Raise if this holder already had a MeritRemoval archived.
  if state.hasMR.contains(mr.holder):
    raise newLoggedException(DataExists, "Already removed this holder's Merit.")

  #Raise if the MeritRemoval was already flagged.
  #First check done as we're likely to be sent SMRs multiple times and signature verifs are expensive.
  if consensus.malicious.hasKey(holder):
    try:
      for mr in consensus.malicious[holder]:
        if (
          ((mr.element1 == removal.element1) and (mr.element2 == removal.element2)) or
          #Test if the Elements are swapped.
          #All this does is prevent a minor annoyance where we could hold the same MeritRemoval twice.
          #Now that MRs are permanent, this doesn't really mean anything.
          ((mr.element1 == removal.element2) and (mr.element2 == removal.element1))
        ):
          raise newLoggedException(DataExists, "Already handled this SignedMeritRemoval.")
    except KeyError as e:
      panic("Failed to get the MeritRemovals for a holder which has MeritRemovals in the cache: " & e.msg)

  #Verify the MeritRemoval's signature.
  if not mr.signature.verify(mr.agInfo(state.holders[mr.holder])):
    raise newLoggedException(ValueError, "Invalid MeritRemoval signature.")

  #Verify the Elements conflict with each other.
  try:
    #Only usage of this function. They should be merged.
    consensus.verify(mr)
  except ValueError as e:
    raise e
  except DataExists as e:
    raise e

  #Save it to the cache.
  if not consensus.malicious.hasKey(holder):
    consensus.malicious[holder] = @[removal]
  else:
    try:
      consensus.malicious[holder].add(removal)
    except KeyError as e:
      panic("Couldn't add a MeritRemoval to a seq we've confirmed exists: " & e.msg)

  #Save the MeritRemoval to the database, marking its part of the cache.
  consensus.db.save(removal)
  consensus.db.saveMaliciousProof(cast[SignedMeritRemoval](removal))

  #Update affected pending Transactions.
  consensus.flag(blockchain, state, mr.holder)

#Remove the Merit from holders who had an implicit Merit Removal.
#As Consensus doesn't track Merit, this just clears their pending MeritRemovals.
#This also removes any votes they may have in the SpamFilter.
proc remove*(
  consensus: var Consensus,
  blockchain: Blockchain,
  state: State,
  holders: set[uint16]
) {.forceCheck: [].} =
  for holder in holders:
    logInfo "Archiving Merit Removal", holder = holder

    #We do not call flag here. MainMerit calls it before remove is called.

    #Clear any cached entries.
    consensus.malicious.del(holder)
    consensus.db.deleteMaliciousProofs(holder)

    #Remove them from the difficulty filters.
    #This could be part of flag, yet difficulty should be firmly agreed on, not just a suggestion.
    #Such an update requires the difficulty to only be lowered when a new Block coordinates it.
    #Because of that, removal from filters is done here.
    #It can also be done in add(SignedMeritRemoval) with a check for the diff would change.
    consensus.filters.send.remove(holder, merit)
    consensus.filters.data.remove(holder, merit)

#Mark all mentioned packets as mentioned, reset pending, finalize finalized Transactions, and check close Transactions.
proc archive*(
  consensus: var Consensus,
  state: State,
  shifted: seq[VerificationPacket],
  elements: seq[BlockElement],
  popped: Epoch,
  changes: StateChanges
) {.forceCheck: [].} =
  #Delete every mentioned hash in the Block from unmentioned.
  for packet in shifted:
    consensus.unmentioned.excl(packet.hash)
    consensus.db.mention(packet.hash)

  #Update the Epoch for every unmentioned Transaction.
  for hash in consensus.unmentioned:
    consensus.incEpoch(hash)

    #Get the status.
    var
      status: TransactionStatus
      merit: int = 0
    try:
      status = consensus.getStatus(hash)
    except IndexError as e:
      panic("Couldn't get the TransactionStatus for an unmentioned Transaction: " & e.msg)

    #If the Transaction was verified, calculate its Merit and see if it's still verified with the new threshold.
    for holder in status.holders:
      if consensus.malicious.hasKey(holder):
        continue
      merit += state[holder, status.epoch]

    #If it's not, unverify it.
    if merit < state.nodeThresholdAt(status.epoch):
      consensus.unverify(hash, status)

    #Make sure the hash is included in unmentioned.
    consensus.db.addUnmentioned(hash)

  #Update the signature/nonces of the specified holder.
  proc updateSignatureAndNonce(
    consensus: var Consensus,
    holder: uint16,
    nonce: int
  ) {.forceCheck: [].} =
    try:
      #The Elements passed aren't sorted; skip out of order Elements.
      if consensus.archived[holder] < nonce:
        #Remove signatures.
        #There won't be any if we only ever saw the unsigned version of this Element.
        for s in 1 .. nonce - consensus.archived[holder]:
          if consensus.signatures[holder].len == 0:
            break
          consensus.signatures[holder].delete(0)
          consensus.db.deleteSignature(holder, consensus.archived[holder] + s)

        #Update the nonces.
        consensus.archived[holder] = nonce
        consensus.db.saveArchived(holder, nonce)
    except KeyError as e:
      panic("Block had Elements with an invalid holder: " & e.msg)

  try:
    for elem in elements:
      case elem:
        of SendDifficulty as sd:
          updateSignatureAndNonce(consensus, sd.holder, sd.nonce)
        of DataDifficulty as dd:
          updateSignatureAndNonce(consensus, dd.holder, dd.nonce)
        else:
          panic("Unsupported Block Element.")
  except KeyError:
    panic("Tried to archive an Element for a non-existent holder.")

  #Finalize every popped family.
  #First requires expanding from TX to family.
  var
    inputs: seq[HashSet[Input]] = newSeq[HashSet[Input]](popped.len)
    families: seq[seq[Hash[256]]] = newSeq[seq[Hash[256]]](popped.len)
    i: int = 0
  #First requires getting every TX from every family.
  for hash in popped.keys():
    try:
      #The Consensus test doesn't actually create transactions; just hashes registered in the cache.
      #Work around this edge case, wrapped in a define to ensure it's never used in a live scenario.
      #This should be impossible when actually run.
      when defined(merosTests):
        if consensus.functions.transactions.getTransaction(hash).inputs.len == 0:
          families[i] = @[hash]
          inc(i)
          continue

      var tx: Transaction = consensus.functions.transactions.getTransaction(hash)
      if (tx of Data) and (tx.inputs[0].hash == Hash[256]()) or (tx.inputs[0].hash == consensus.genesis):
        families[i].add(hash)
      else:
        inputs[i] = consensus.functions.transactions.getAndPruneFamilyUnsafe(tx.inputs[0])
        #Part of a different family.
        if inputs.len == 0:
          continue
        for input in inputs[i]:
          families[i] &= consensus.functions.transactions.getSpenders(input)
        families[i] = families[i].deduplicate()
      inc(i)
    except IndexError:
      panic("Couldn't get a Transaction we're finalizing: " & $hash)
  inputs.setLen(i)
  families.setLen(i)

  #Iterate over each family using a queue.
  var cyclical: bool = false
  while families.len != 0:
    var
      lenAtStart: int = families.len
      i: int = 0
    while i < families.len:
      try:
        consensus.finalize(state, inputs[i], families[i], cyclical)
      except UnfinalizedParents:
        inc(i)
        continue
      #We should be able to use del here, as del should take the last element and move it.
      #Therefore, the pair indexes should be the same. That said, it's best to pick the safer option.
      inputs.delete(i)
      families.delete(i)

    if lenAtStart == families.len:
      if cyclical:
        panic("Couldn't finalize the last family.")
      for f in 1 ..< families.len:
        families[0] &= families[f]
      families.setLen(1)
      cyclical = true
      logInfo "Cyclical transaction family found ", family = families[0]

  #Reclaulcate every close Status.
  var toDelete: seq[Hash[256]] = @[]
  for hash in consensus.close:
    var status: TransactionStatus
    try:
      status = consensus.getStatus(hash)
    except IndexError:
      panic("Couldn't get the status of a Transaction that's close to being verified: " & $hash)

    #Remove finalized Transactions.
    if status.merit != -1:
      toDelete.add(hash)
      continue

    #Recalculate Merit.
    consensus.calculateMerit(state, hash, status)
    #Remove verified Transactions.
    if status.verified:
      toDelete.add(hash)
      continue

  #Delete all close hashes marked for deletion.
  for hash in toDelete:
    consensus.close.excl(hash)

  #Update the filters.
  var difficulties: Table[uint16, uint32] = initTable[uint16, uint32]()
  for holder in changes.pending:
    try:
      difficulties[holder] = consensus.db.loadSendDifficulty(holder)
    except DBReadError:
      discard
  consensus.filters.send.handleBlock(state, changes, difficulties)

  difficulties = initTable[uint16, uint32]()
  for holder in changes.pending:
    try:
      difficulties[holder] = consensus.db.loadDataDifficulty(holder)
    except DBReadError:
      discard
  consensus.filters.data.handleBlock(state, changes, difficulties)

  #If the holder just got their first vote, make sure their difficulty is counted.
  if state[changes.incd, state.processedBlocks] == 50:
    try:
      consensus.filters.send.update(state, changes.incd, consensus.db.loadSendDifficulty(changes.incd))
    except DBReadError:
      discard

    try:
      consensus.filters.data.update(state, changes.incd, consensus.db.loadDataDifficulty(changes.incd))
    except DBReadError:
      discard

  #If the amount of holders increased, update the signatures and archived nonce tables.
  if state.holders.len > consensus.archived.len:
    consensus.signatures[uint16(consensus.archived.len)] = @[]
    consensus.archived[uint16(consensus.archived.len)] = -1

proc revert*(
  consensus: var Consensus,
  blockchain: Blockchain,
  state: State,
  transactions: Transactions,
  height: int
) {.forceCheck: [].} =
  #[
  We need to find the oldest Element nonce we're reverting past.
  We need to delete all Elements from that nonce (inclusive) to the tip.
  If we delete an Element at the tip which wasn't archived, we also need to delete its signature.
  We need to update the archived nonces.
  We need to make sure the SendDifficulty and DataDifficulty are updated accordingly.

  We need to delete malicious proofs we no longer have the signature for.
  We shouldn't need to touch the malicious cache.

  We need to revert the SpamFilters. We can do this by rebuilding them, however inefficient it is.

  We need to prune statuses of Transactions which are about to be pruned.
  We need to make sure to preserve a copy of Transactions in VC MRs which are about to be pruned, if the MRs are still in the malicious cache.
  ]#

  var
    aboutToBePruned: HashSet[Hash[256]]
    revertedToNonces: Table[uint16, int] = initTable[uint16, int]()
  for b in countdown(blockchain.height - 1, height):
    var revertedBlock: Block
    try:
      revertedBlock = blockchain[b]
    except IndexError as e:
      panic("Couldn't get a Block when iterating from the height to another height: " & e.msg)

    try:
      discard transactions[revertedBlock.header.hash]
      aboutToBePruned = transactions.discoverUnorderedTree(revertedBlock.header.hash, aboutToBePruned)
    except IndexError:
      discard
    try:
      aboutToBePruned.incl(newData(blockchain.genesis, blockchain[b].header.hash.serialize()).hash)
    except IndexError as e:
      panic("Failed to get a Block we're reverting past: " & e.msg)
    except ValueError as e:
      panic("Consensus failed to mark the Block Data for pruning: " & e.msg)

    for elem in revertedBlock.body.elements:
      case elem:
        of SendDifficulty as sd:
          if sd.nonce < revertedToNonces.getOrDefault(sd.holder, high(int)):
            revertedToNonces[sd.holder] = sd.nonce
        of DataDifficulty as dd:
          if dd.nonce < revertedToNonces.getOrDefault(dd.holder, high(int)):
            revertedToNonces[dd.holder] = dd.nonce
        else:
          panic("Unknown Element included in Block.")

  #Delete Elements which we reverted past.
  for holder in revertedToNonces.keys():
    try:
      for n in revertedToNonces[holder] .. consensus.db.load(holder):
        consensus.db.delete(holder, n)
        consensus.db.deleteSignature(holder, n)

      #Update the holder's nonce.
      consensus.archived[holder] = revertedToNonces[holder] - 1
      consensus.db.override(holder, revertedToNonces[holder] - 1)

      #Also delete cached signatures since we wiped out Elements in the middle of their chain.
      consensus.signatures[holder] = @[]

      #Also update the SendDifficulty and DataDifficulty, if required.
      var
        found: bool = false
        other: BlockElement
      if consensus.db.loadSendDifficultyNonce(holder) >= revertedToNonces[holder]:
        for n in countdown(consensus.archived[holder], 0):
          try:
            other = consensus.db.load(holder, n)
          except DBReadError as e:
            panic("Couldn't grab a BlockElement when iterating down from the last archived nonce: " & e.msg)

          if other of SendDifficulty:
            found = true
            consensus.db.override(cast[SendDifficulty](other))
            break

        if not found:
          consensus.db.deleteSendDifficulty(holder)

      found = false
      if consensus.db.loadDataDifficultyNonce(holder) >= revertedToNonces[holder]:
        for n in countdown(consensus.archived[holder], 0):
          try:
            other = consensus.db.load(holder, n)
          except DBReadError as e:
            panic("Couldn't grab a BlockElement when iterating down from the last archived nonce: " & e.msg)

          if other of DataDifficulty:
            found = true
            consensus.db.override(cast[DataDifficulty](other))
            break

        if not found:
          consensus.db.deleteDataDifficulty(holder)
    except KeyError as e:
      panic("Couldn't get the reverted to nonce/archived nonce of a holder with one: " & e.msg)

  #[
  Rebuild the filters.
  We shouldn't need those copies. I originally tried to inline this.
  That said, newSpamFilterObj printed it was handed the initial value yet didn't set it.
  My theory, which I can't think of why this would happen, is that it overwrote the SpamFilter during construction, and then grabbed its unset value.
  I truly don't know. This works. Don't try to inline it.
  -- Kayaba
  ]#
  var
    sendDiff: uint32 = consensus.filters.send.initialDifficulty
    dataDiff: uint32 = consensus.filters.data.initialDifficulty
  consensus.filters.send = newSpamFilterObj(sendDiff)
  consensus.filters.data = newSpamFilterObj(dataDiff)
  for h in 0 ..< state.holders.len:
    try:
      consensus.filters.send.update(state, uint16(h), consensus.db.loadSendDifficulty(uint16(h)))
    except DBReadError:
      discard

    try:
      consensus.filters.data.update(state, uint16(h), consensus.db.loadDataDifficulty(uint16(h)))
    except DBReadError:
      discard

  #Prune statuses of Transactions about to be pruned.
  for hash in aboutToBePruned:
    consensus.delete(hash)

  #Iterate over every pending MeritRemoval.
  #If it's a VC MeritRemoval, and the verified Transaction is about to be pruned, back it up.
  for holder in consensus.malicious.keys():
    try:
      var i: int = 0
      while i < consensus.malicious[holder].len:
        if consensus.malicious[holder][i].element1 of Verification:
          if (
            aboutToBePruned.contains(
              cast[Verification](consensus.malicious[holder][i].element1).hash
            ) or
            aboutToBePruned.contains(
              cast[Verification](consensus.malicious[holder][i].element2).hash
            )
          ):
            if consensus.malicious[holder].len == 1:
              consensus.malicious.del(holder)
              break
            consensus.malicious[holder].del(i)
            continue
        inc(i)
    except KeyError:
      panic("Couldn't get a malicious Merit Holder's Merit Removals: " & e.msg)
    except IndexError:
      panic("Couldn't get a Transaction that is about to be pruned.")

proc postRevert*(
  consensus: var Consensus,
  blockchain: Blockchain,
  state: State,
  transactions: Transactions
) {.forceCheck: [].} =
  #[
  We need to add statuses of Transactions which are back in the Transactions cache to the Consensus cache.
  This requires recalculating their Epoch.
  We need to remove Verifications we no longer have the signatures for from every status in the cache.

  We need to revert close. We can do this by rebuilding it, however inefficient it is.

  We need to revert unmentioned. We can do this by rebuilding it, however inefficient it is.
  ]#

  var revertedStatuses: TableRef[Hash[256], TransactionStatus] = newTable[Hash[256], TransactionStatus]()
  for hash in consensus.cachedTransactions:
    try:
      revertedStatuses[hash] = consensus.getStatus(hash)
    except IndexError as e:
      panic("Transaction with a status in the cache doesn't have a status: " & e.msg)

  for hash in transactions.transactions.keys():
    if not revertedStatuses.hasKey(hash):
      try:
        revertedStatuses[hash] = consensus.getStatus(hash)
      except IndexError as e:
        panic("Transaction in the cache doesn't have a status: " & e.msg)

  #[
  Iterate over the last 5 blocks and find out:
  - When Transactions were mentioned.
  - What holders have archived Verifications.
  ]#
  var
    mentioned: Table[Hash[256], int] = initTable[Hash[256], int]()
    holders: Table[Hash[256], HashSet[uint16]] = initTable[Hash[256], HashSet[uint16]]()
  for i in max(blockchain.height - 5, 0) ..< blockchain.height:
    try:
      for packet in blockchain[i].body.packets:
        #If we haven't seen this Transaction yet, register it and create a HashSet.
        if not mentioned.hasKey(packet.hash):
          mentioned[packet.hash] = i
          holders[packet.hash] = initHashSet[uint16]()

        #Add the holders to the set.
        for holder in packet.holders:
          try:
            holders[packet.hash].incl(holder)
          except KeyError as e:
            panic("Packet within the last 5 blocks doesn't have a holders set initialized: " & e.msg)
    except IndexError as e:
      panic("Couldn't get a Block when iterating from 0 to the height: " & e.msg)

  #Clear unmentioned and close.
  consensus.unmentioned = initHashSet[Hash[256]]()
  consensus.close = initHashSet[Hash[256]]()

  #Update merit, holders, epoch, and unmentioned, while generating a queue.
  var status: TransactionStatus
  for hash in revertedStatuses.keys():
    #Grab the status.
    try:
      status = revertedStatuses[hash]
    except KeyError as e:
      panic("Couldn't grab a status that's in the newly formed cache: " & e.msg)

    #Set merit to -1 so this TransactionStatus is registered as pending.
    status.merit = -1

    #Set the holders and epoch.
    try:
      status.holders = holders[hash]
      status.epoch = mentioned[hash] + 6
    #If this raised a KeyError, they were never mentioned.
    except KeyError:
      status.holders = initHashSet[uint16]()
      consensus.setUnmentioned(hash)
      status.epoch = blockchain.height + 6

    #Add back the pending holders.
    status.holders = status.holders + status.pending

    #Mark it as unverified until proven otherwise.
    if status.verified:
      consensus.unverify(hash, status, revertedStatuses)

  #Calculate every Transaction's Merit.
  for hash in revertedStatuses.keys():
    try:
      consensus.calculateMerit(state, hash, revertedStatuses[hash], revertedStatuses)
    except KeyError as e:
      panic("Couldn't grab a status that's in the formed cache: " & e.msg)

  #Save back the statuses.
  for hash in revertedStatuses.keys():
    try:
      consensus.setStatus(hash, revertedStatuses[hash])
    except KeyError as e:
      panic("Couldn't get a status with a key from keys: " & e.msg)
