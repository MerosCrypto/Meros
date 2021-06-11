import algorithm
import sequtils, sets, tables

import chronos

import ../lib/[Errors, Util, Hash, Sketcher]

import ../Database/Merit/Block as BlockFile
import ../Database/Merit/State

import ../Database/Consensus/Elements/Elements
import ../Database/Consensus/TransactionStatus

import ../Database/Transactions/Transactions

import objects/[MessageObj, SketchyBlockObj, SyncRequestObj, SyncManagerObj]
export SketchyBlock, SyncManagerObj

import Peer
export Peer

#Custom future which includes a set timeout.
type SyncFuture[T] = ref object
  manager: SyncManager
  id: int

  future: Future[T]
  timeout: int

proc newSyncFuture[T](
  manager: SyncManagerObj.SyncManager,
  id: int,
  future: Future[T],
  timeout: int
): SyncFuture[T] {.inline, forceCheck: [].} =
  SyncFuture[T](
    manager: manager,
    id: id,

    future: future,
    timeout: timeout
  )

#Await which completes the future after the timeout, raising DataMissing if the actual future had yet to complete.
proc syncAwait*[T](
  future: SyncFuture[T]
): Future[T] {.forceCheck: [
  DataMissing
], async.} =
  var timeout: Future[bool]
  try:
    timeout = withTimeout(future.future, seconds(future.timeout))
  except Exception as e:
    panic("Couldn't create a timeout for this SyncRequest: " & e.msg)

  var timedOut: bool
  try:
    timedOut = not await timeout
  except Exception as e:
    panic("Couldn't create await a timeout: " & e.msg)

  if not timedOut:
    logDebug "Sync Request resolved", id = future.id

  when T is seq[tuple[ip: string, port: int]]:
    if timedOut:
      var request: PeersSyncRequest
      try:
        request = cast[PeersSyncRequest](future.manager.requests[future.id])
      except KeyError as e:
        panic("Couldn't get a SyncRequest which timed out: " & e.msg)

      future.manager.requests.del(future.id)
      return request.pending
  else:
    if timedOut:
      logDebug "SyncRequest timed out", id = future.id
      future.manager.requests.del(future.id)
      raise newLoggedException(DataMissing, "SyncRequest timed out.")

  try:
    result = future.future.read()
  except ValueError as e:
    panic("Couldn't read the value of a completed future: " & e.msg)

proc syncTransaction*(
  manager: SyncManager,
  hash: Hash[256]
): SyncFuture[Transaction] {.forceCheck: [].} =
  #Get an ID.
  var id: int = manager.id
  inc(manager.id)

  logDebug "Syncing Transaction", id = id, hash = hash

  #Create the future.
  result = newSyncFuture[Transaction](
    manager,
    id,
    newFuture[Transaction]("syncTransaction"),
    2
  )

  #Create the request and register it.
  var request: TransactionSyncRequest = result.future.newTransactionSyncRequest(hash)
  manager.requests[id] = request

  #Send the request to every peer.
  for peer in manager.peers.values():
    try:
      asyncCheck peer.syncRequest(id, request.msg)
    except Exception as e:
      panic("Couldn't send a TransactionRequest to a Peer: " & e.msg)

proc syncVerificationPackets*(
  manager: SyncManager,
  hash: Hash[256],
  salt: string,
  sketchHashes: seq[uint64]
): SyncFuture[seq[VerificationPacket]] {.forceCheck: [].} =
  #Get an ID.
  var id: int = manager.id
  inc(manager.id)

  logDebug "Syncing Verification Packets", id = id, hash = hash

  #Create the future.
  result = newSyncFuture[seq[VerificationPacket]](
    manager,
    id,
    newFuture[seq[VerificationPacket]]("syncVerificationPackets"),
    3
  )

  #Create the request and register it.
  var request: SketchHashSyncRequests = result.future.newSketchHashSyncRequests(hash, salt, sketchHashes)
  manager.requests[id] = request

  #Send the request to every peer.
  for peer in manager.peers.values():
    try:
      asyncCheck peer.syncRequest(id, request.msg)
    except Exception as e:
      panic("Couldn't send a SketchHashSyncRequests to a Peer: " & e.msg)

proc syncSketchHashes*(
  manager: SyncManager,
  hash: Hash[256],
  sketchCheck: Hash[256]
): SyncFuture[seq[uint64]] {.forceCheck: [].} =
  #Get an ID.
  var id: int = manager.id
  inc(manager.id)

  logDebug "Syncing Sketch Hashes", id = id, hash = hash

  #Create the future.
  result = newSyncFuture[seq[uint64]](
    manager,
    id,
    newFuture[seq[uint64]]("syncSketchHashes"),
    3
  )

  #Create the request and register it.
  var request: SketchHashesSyncRequest = result.future.newSketchHashesSyncRequest(hash, sketchCheck)
  manager.requests[id] = request

  #Send the request to every peer.
  for peer in manager.peers.values():
    try:
      asyncCheck peer.syncRequest(id, request.msg)
    except Exception as e:
      panic("Couldn't send a SketchHashesSyncRequest to a Peer: " & e.msg)

#Sync a Block's missing Transactions/VerificationPackets.
#The second return value is sorted.
proc sync*(
  manager: SyncManager,
  state: State,
  newBlock: SketchyBlock,
  sketcher: seq[VerificationPacket]
): Future[(Block, seq[BlockElement])] {.forceCheck: [
  ValueError,
  DataMissing
], async.} =
  var
    #Block's Verification Packets.
    packets: seq[VerificationPacket] = @[]
    #Missing Sketch Hashes.
    missingPackets: seq[uint64] = @[]

    #Transactions included in the Block.
    includedTXs: HashSet[Hash[256]] = initHashSet[Hash[256]]()

    #Missing Transactions.
    missingTXs: seq[Hash[256]] = @[]
    #Transactions.
    transactions: Table[Hash[256], Transaction] = initTable[Hash[256], Transaction]()

  try:
    #Try to resolve the Sketch.
    var sketchResult: SketchResult
    try:
      sketchResult = sketcher.merge(
        newBlock.sketch,
        newBlock.capacity,
        newBlock.data.header.sketchSalt
      )
    except SaltError:
      raise newLoggedException(ValueError, "Our sketch had a collision.")

    #If the sketch resolved, save the found packets/missing items.
    packets = sketchResult.packets
    missingPackets = sketchResult.missing

    #Verify the sketchCheck Merkle to verify the sketch decoded properly.
    newBlock.data.header.sketchCheck.verifySketchCheck(
      newBlock.data.header.sketchSalt,
      packets,
      missingPackets
    )

    logDebug "Resolved Sketch and verified Sketch Check", hash = newBlock.data.header.hash
  #Sketch failed to decode.
  except ValueError:
    logDebug "Sketch resolution failed, syncing Sketch Hashes", hash = newBlock.data.header.hash

    #Clear packets.
    packets = @[]

    #Generate a Table of hashes we have in the Sketcher to their packet.
    var lookup: Table[uint64, VerificationPacket] = initTable[uint64, VerificationPacket]()
    for elem in sketcher:
      lookup[sketchHash(newBlock.data.header.sketchSalt, elem)] = elem

    #Sync the list of sketch hashes.
    try:
      missingPackets = await syncAwait manager.syncSketchHashes(
        newBlock.data.header.hash,
        newBlock.data.header.sketchCheck
      )
    except DataMissing as e:
      raise e
    except Exception as e:
      panic("Syncing a Block's SketchHashes threw an Exception despite catching all thrown Exceptions: " & e.msg)

    #Remove packets present in our sketcher.
    var m: int = 0
    while m < missingPackets.len:
      if lookup.hasKey(missingPackets[m]):
        try:
          packets.add(lookup[missingPackets[m]])
        except KeyError as e:
          panic("Couldn't add a packet we already have back to the packets list: " & e.msg)
        missingPackets.del(m)
      inc(m)

    logDebug "Synced Sketch Hashes", hash = newBlock.data.header.hash

  if uint32(packets.len + missingPackets.len) != newBlock.data.header.packetsQuantity:
    raise newLoggedException(ValueError, "Invalid packets quantity.")

  #Sync the missing VerificationPackets.
  if missingPackets.len != 0:
    try:
      packets &= await syncAwait manager.syncVerificationPackets(newBlock.data.header.hash, newBlock.data.header.sketchSalt, missingPackets)
    except DataMissing as e:
      raise e
    except Exception as e:
      panic("Syncing a Block's VerificationPackets threw an Exception despite catching all thrown Exceptions: " & e.msg)

  #Check the header's packets quantity.
  if uint32(packets.len) != newBlock.data.header.packetsQuantity:
    raise newLoggedException(ValueError, "Header's amount of packets and sketchCheck don't line up.")

  #Verify the contents Merkle.
  try:
    packets = newBlock.data.header.contents.verifyContents(
      packets,
      newBlock.data.body.elements
    )
  except ValueError as e:
    raise e

  #Create the Block.
  result[0] = newBlock.data
  result[0].body.packets = packets

  #Check the Block's aggregate.
  try:
    if not result[0].verifyAggregate(manager.functions.merit.getPublicKey):
      raise newLoggedException(ValueError, "Block has an invalid aggregate.")
  except IndexError as e:
    panic("Passing a function which can raise an IndexError raised an IndexError: " & e.msg)

  logDebug "Verified contents and aggregate", hash = newBlock.data.header.hash

  #Find missing Transactions.
  for packet in result[0].body.packets:
    includedTXs.incl(packet.hash)
    try:
      discard manager.functions.transactions.getTransaction(packet.hash)
    except IndexError:
      missingTXs.add(packet.hash)
      continue

    #Also check if this packet is for a beaten Transaction.
    #If so, raise.
    try:
      if manager.functions.consensus.getStatus(packet.hash).beaten:
        raise newLoggedException(ValueError, "Block tries to archive Verifications for beaten Transactions.")
    except IndexError as e:
      panic("Couldn't get the status for a Transaction we have: " & e.msg)

  #Sync the missing Transactions.
  if missingTXs.len != 0:
    #Get the Transactions.
    for tx in missingTXs:
      try:
        transactions[tx] = await syncAwait manager.syncTransaction(tx)
      except DataMissing:
        #Since we did not get this Transaction, this Block is trying to archive unknown Verification OR we just don't have a proper Peer set.
        #The first is assumed.
        raise newLoggedException(ValueError, "Block tries to archive unknown Verifications.")
      except Exception as e:
        panic("Syncing a Transaction threw an Exception despite catching all thrown Exceptions: " & e.msg)

  logDebug "Synced missing Transactions", hash = newBlock.data.header.hash

  #List of Transactions we have yet to process.
  var todo: Table[Hash[256], Transaction]
  #While we still have transactions to do...
  while transactions.len > 0:
    #Clear todo.
    todo = initTable[Hash[256], Transaction]()
    #Iterate over every transaction.
    for tx in transactions.values():
      block thisTX:
        #Handle initial Datas.
        var first: bool = (tx of Data) and (tx.inputs[0].hash == Hash[256]())

        #Make sure we have already added every input.
        if not first:
          for input in tx.inputs:
            try:
              discard manager.functions.transactions.getTransaction(input.hash)
            #This TX is missing an input.
            except IndexError:
              #Look for the input in the pending Transactions.
              if transactions.hasKey(input.hash):
                #If it's there, add this Transaction to be handled later.
                todo[tx.hash] = tx
                break thisTX
              else:
                raise newLoggedException(ValueError, "Block includes Verifications of a Transaction which has not had all its inputs mentioned in previous blocks/this block.")

        #Handle the Transaction.
        case tx:
          of Claim as claim:
            try:
              manager.functions.transactions.addClaim(claim, true)
            except ValueError:
              raise newLoggedException(ValueError, "Block includes Verifications of an invalid Transaction.")
            except DataExists:
              continue

          of Send as send:
            try:
              await manager.functions.transactions.addSend(send, true)
            except ValueError:
              raise newLoggedException(ValueError, "Block includes Verifications of an invalid Transaction.")
            except DataExists:
              continue
            except Exception as e:
              panic("addSend raised an Exception despite catching all errors: " & e.msg)

          of Data as data:
            try:
              await manager.functions.transactions.addData(data, true)
            except ValueError:
              raise newLoggedException(ValueError, "Block includes Verifications of an invalid Transaction.")
            except DataExists:
              continue
            except Exception as e:
              panic("addData raised an Exception despite catching all errors: " & e.msg)

          else:
            panic("Synced an Transaction of an unsyncable type.")

    #Panic if the queue length didn't change.
    if transactions.len == todo.len:
      panic("Transaction queue length is unchanged.")

    #Set transactions to todo.
    transactions = todo

  logDebug "Added missing Transactions", hash = newBlock.data.header.hash

  #Verify the included packets.
  var
    #Holders for a TX from this Block specifically.
    holdersForTX: Table[Hash[256], seq[uint16]]
    #Track any competitors the Transactions have. Used to create MRs.
    competitors: Table[Hash[256], seq[Hash[256]]] = initTable[Hash[256], seq[Hash[256]]]()
    thisTXsCompetitors: seq[Hash[256]]
  for packet in result[0].body.packets:
    holdersForTX[packet.hash] = packet.holders

    #If we already tracked this TX, this Block doesn't only have unique packets.
    if competitors.hasKey(packet.hash):
      raise newLoggedException(ValueError, "Block includes two packets for the same Transaction.")
    thisTXsCompetitors = @[]

    #Verify the predecessors of every Transaction are already mentioned on the chain OR also in this Block.
    var tx: Transaction
    try:
      tx = manager.functions.transactions.getTransaction(packet.hash)
    except IndexError as e:
      panic("Couldn't get a Transaction we're confirmed to have: " & e.msg)

    if not ((tx of Data) and (cast[Data](tx).isFirstData or (tx.inputs[0].hash == manager.genesis))):
      for input in tx.inputs:
        if (
          (not (tx of Claim)) and
          (not (manager.functions.consensus.hasArchivedPacket(input.hash) or includedTXs.contains(input.hash)))
        ):
          raise newLoggedException(ValueError, "Block's Transactions have predecessors which have yet to be mentioned on chain.")

        #Track competitors while we're here.
        thisTXsCompetitors &= manager.functions.transactions.getSpenders(input)

    thisTXsCompetitors = thisTXsCompetitors.deduplicate()
    for i in 0 ..< thisTXsCompetitors.len:
      if thisTXsCompetitors[i] == packet.hash:
        thisTXsCompetitors.del(i)
        break
    competitors[packet.hash] = thisTXsCompetitors

    #Get the status.
    var status: TransactionStatus
    try:
      status = manager.functions.consensus.getStatus(packet.hash)
    except IndexError as e:
      panic("Couldn't get the status of a Transaction we're confirmed to have: " & e.msg)

    #Verify the Transaction is still in Epochs and wasn't beaten.
    if status.finalized:
      raise newLoggedException(ValueError, "Block has a Verification for a Transaction either out of Epochs or beaten.")

    #Check the packet's holders.
    for holder in packet.holders:
      #Verify every holder in the packet has yet to be archived.
      if status.holders.contains(holder):
        #If they're in holders. they're either an archived holder or a pending holder.
        if not status.packet.holders.contains(holder):
          raise newLoggedException(ValueError, "Block archives holders who are already archived.")

      if int(holder) >= state.merit.len:
        raise newLoggedException(ValueError, "Block has a Verification from a non-existent holder.")

  #Verify the included Elements.
  result[1] = result[0].body.elements
  var
    newNonces: Table[uint16, int] = initTable[uint16, int]()
    hasElem: set[uint16] = {}
  #Sort by nonce so we don't risk a gap.
  result[1].sort(
    proc (
      e1: BlockElement,
      e2: BlockElement
    ): int {.forceCheck: [].} =
      var
        e1Nonce: int = -1
        e2Nonce: int = -1

      case e1:
        of SendDifficulty as sendDiff:
          e1Nonce = sendDiff.nonce
        of DataDifficulty as dataDiff:
          e1Nonce = dataDiff.nonce

      case e2:
        of SendDifficulty as sendDiff:
          e2Nonce = sendDiff.nonce
        of DataDifficulty as dataDiff:
          e2Nonce = dataDiff.nonce

      if e1Nonce < e2Nonce: -1 else: 1
  )

  #Workaround for some scoping issues with manager during nested functions.
  var managerLocal: SyncManager = manager
  for e, elem in result[1]:
    proc handleElementWithNonce(
      elem: SendDifficulty or DataDifficulty
    ) {.forceCheck: [
      ValueError
    ].} =
      if not newNonces.hasKey(elem.holder):
        newNonces[elem.holder] = managerLocal.functions.consensus.getArchivedNonce(elem.holder)

      try:
        if elem.nonce > newNonces[elem.holder] + 1:
          raise newLoggedException(ValueError, "Block has an Element which skips a nonce.")
        elif elem.nonce < newNonces[elem.holder] + 1:
          if elem.nonce <= managerLocal.functions.consensus.getArchivedNonce(elem.holder):
            var archived: Element
            try:
              archived = managerLocal.functions.consensus.getElement(elem.holder, elem.nonce)
            except IndexError as e:
              panic("Couldn't get a Element with a nonce lower than the newest nonce for this holder: " & e.msg)
            if elem == archived:
              raise newLoggedException(ValueError, "Block contains an already archived Element.")
            result[0].body.removals.incl(elem.holder)
          else:
            for e2 in 0 ..< e:
              var otherNonce: int
              #Case statement macro didn't resolve properly.
              if result[1][e2] of SendDifficulty:
                otherNonce = cast[SendDifficulty](result[1][e2]).nonce
              elif result[1][e2] of DataDifficulty:
                otherNonce = cast[DataDifficulty](result[1][e2]).nonce
              else:
                panic("Checking the nonce of an unknown Block Element.")

              if (elem.holder == result[1][e2].holder) and (elem.nonce == otherNonce):
                if elem == result[1][e2]:
                  raise newLoggedException(ValueError, "Block contains the same Element twice.")
                result[0].body.removals.incl(elem.holder)
        inc(newNonces[elem.holder])
      except KeyError:
        panic("Table doesn't have a value for a key we made sure we had.")

    try:
      case elem:
        of SendDifficulty as sendDiff:
          handleElementWithNonce(sendDiff)
        of DataDifficulty as dataDiff:
          handleElementWithNonce(dataDiff)
    except ValueError as e:
      raise e
    hasElem.incl(elem.holder)

  #Generate any Competing Verification Merit Removals.
  for packet in result[0].body.packets:
    try:
      thisTXsCompetitors = competitors[packet.hash]
    except KeyError:
      panic("Didn't register a competitors variable for a Transaction in this Block.")
    if thisTXsCompetitors.len == 0:
      continue

    for holder in packet.holders:
      if result[0].body.removals.contains(holder):
        continue

      for competitor in thisTXsCompetitors:
        var compStatus: TransactionStatus
        try:
          compStatus = manager.functions.consensus.getStatus(competitor)
        except IndexError as e:
          panic("Couldn't get a status for a Transaction which spends an input mentioned in this Block: " & e.msg)

        try:
          if (
            #Archived Competing Verification.
            (compStatus.holders.contains(holder) and (not compStatus.pending.contains(holder))) or
            #Competing Verification in this same Block.
            (holdersForTX.hasKey(competitor) and holdersForTX[competitor].contains(holder))
          ):
            result[0].body.removals.incl(holder)

          #If they have a pending Verification, we could create a Signed MeritRemoval at this point in time.
          #Basically a new form of https://github.com/MerosCrypto/Meros/issues/120.
          elif compStatus.pending.contains(holder):
            discard
        except KeyError as e:
          panic("Couldn't get the holders for a Transaction in this Block: " & e.msg)

proc syncBlockBody*(
  manager: SyncManager,
  hash: Hash[256],
  contents: Hash[256],
  capacity: uint32
): SyncFuture[SketchyBlockBody] {.forceCheck: [].} =
  #Get an ID.
  var id: int = manager.id
  inc(manager.id)

  logDebug "Syncing Block Body", id = id, hash = hash

  #Create the future.
  result = newSyncFuture[SketchyBlockBody](
    manager,
    id,
    newFuture[SketchyBlockBody]("syncBlockBody"),
    5
  )

  #Create the request and register it.
  var request: BlockBodySyncRequest = result.future.newBlockBodySyncRequest(hash, contents, capacity)
  manager.requests[id] = request

  #Send the request to every peer.
  for peer in manager.peers.values():
    try:
      asyncCheck peer.syncRequest(id, request.msg)
    except Exception as e:
      panic("Couldn't send a BlockBodySyncRequest to a Peer: " & e.msg)

proc syncBlockHeaderWithoutHashing*(
  manager: SyncManager,
  hash: Hash[256]
): SyncFuture[BlockHeader] {.forceCheck: [].} =
  #Get an ID.
  var id: int = manager.id
  inc(manager.id)

  logDebug "Syncing Block Header", id = id, hash = hash

  #Create the future.
  result = newSyncFuture[BlockHeader](
    manager,
    id,
    newFuture[BlockHeader]("syncBlockHeaderWithoutHashing"),
    5
  )

  #Create the request and register it.
  var request: BlockHeaderSyncRequest = result.future.newBlockHeaderSyncRequest(hash)
  manager.requests[id] = request

  #Send the request to every peer.
  for peer in manager.peers.values():
    try:
      asyncCheck peer.syncRequest(id, request.msg)
    except Exception as e:
      panic("Couldn't send a BlockHeaderSyncRequest to a Peer: " & e.msg)

#Sync a missing BlockList.
proc syncBlockList*(
  manager: SyncManager,
  amount: int,
  hash: Hash[256]
): SyncFuture[seq[Hash[256]]] {.forceCheck: [].} =
  #Get an ID.
  var id: int = manager.id
  inc(manager.id)

  logDebug "Syncing Block List", id = id, amount = amount

  #Create the future.
  result = newSyncFuture[seq[Hash[256]]](
    manager,
    id,
    newFuture[seq[Hash[256]]]("syncBlockList"),
    3
  )

  #Create the request and register it.
  var request: BlockListSyncRequest = result.future.newBlockListSyncRequest(amount, hash)
  manager.requests[id] = request

  #Send the request to every peer.
  for peer in manager.peers.values():
    try:
      asyncCheck peer.syncRequest(id, request.msg)
    except Exception as e:
      panic("Couldn't send a BlockListSyncRequest to a Peer: " & e.msg)

proc syncPeers*(
  manager: SyncManager
): SyncFuture[seq[tuple[ip: string, port: int]]] {.forceCheck: [].} =
  #Get an ID.
  var id: int = manager.id
  inc(manager.id)

  logDebug "Syncing Peers", id = id

  #Create the future.
  result = newSyncFuture[seq[tuple[ip: string, port: int]]](
    manager,
    id,
    newFuture[seq[tuple[ip: string, port: int]]]("syncPeers"),
    3
  )

  #Create the request and register it.
  var request: PeersSyncRequest = result.future.newPeersSyncRequest(manager.peers.len)
  manager.requests[id] = request

  #Send the request to every peer.
  for peer in manager.peers.values():
    if not peer.sync.isNil:
      try:
        asyncCheck peer.syncRequest(id, request.msg)
      except Exception as e:
        panic("Couldn't send a BlockListSyncRequest to a Peer: " & e.msg)
