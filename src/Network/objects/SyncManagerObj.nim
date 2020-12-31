import sets, tables

import chronos

import ../../lib/[Errors, Util, Hash, Merkle, Sketcher]

import ../../objects/GlobalFunctionBoxObj

import ../../Database/Merit/Block
import ../../Database/Consensus/Elements/Elements
import ../../Database/Transactions/Transaction as TransactionFile

import MessageObj
import SocketObj
import SyncRequestObj
import SketchyBlockObj

import ../Peer as PeerFile

import ../Serialize/SerializeCommon

import ../Serialize/Merit/[
  SerializeBlockHeader,
  SerializeBlockBody,
  ParseBlockHeader,
  ParseBlockBody
]

import ../Serialize/Consensus/[
  SerializeElement,
  SerializeVerificationPacket,
  ParseVerificationPacket
]

import ../Serialize/Transactions/[
  SerializeClaim,
  SerializeSend,
  SerializeData,
  ParseClaim,
  ParseSend,
  ParseData
]

type SyncManager* = ref object
  functions*: GlobalFunctionBox
  genesis*: Hash[256]

  protocol*: uint
  network*: uint
  services*: uint
  port*: int

  peers*: TableRef[int, Peer]

  #Current Requests.
  requests*: Table[int, SyncRequest]
  #Next usable Request ID.
  id*: int

proc newSyncManager*(
  protocol: uint,
  network: uint,
  port: int,
  peers: TableRef[int, Peer],
  functions: GlobalFunctionBox
): SyncManager {.forceCheck: [].} =
  try:
    result = SyncManager(
      functions: functions,
      genesis: functions.merit.getBlockByNonce(0).header.last,

      protocol: protocol,
      network: network,

      port: port,

      peers: peers,

      requests: initTable[int, SyncRequest](),
      id: 0
    )
  except IndexError as e:
    panic("Couldn't get the genesis Block: " & e.msg)

func updateServices*(
  manager: SyncManager,
  service: uint
) {.inline, forceCheck: [].} =
  manager.services = manager.services or service

#Handle a SyncRequest's Response.
proc handleResponse[SyncRequestType, ResultType, CheckType](
  manager: SyncManager,
  peer: Peer,
  msg: Message,
  parse: proc (
    serialization: string,
    check: CheckType
  ): ResultType {.gcsafe, raises: [
    ValueError
  ].}
) {.forceCheck: [
  PeerError
].} =
  #Verify there's a Sync Request to check.
  if peer.requests.len == 0:
    raise newLoggedException(PeerError, "Peer sent us data without any pending SyncRequests.")

  #Check if the message is DataMissing.
  if msg.content == MessageType.DataMissing:
    peer.requests.delete(0)
    return

  #Verify the Request is still active.
  if not manager.requests.hasKey(peer.requests[0]):
    peer.requests.delete(0)
    return

  try:
    #Verify this response is valid for the SyncRequest type.
    if not (manager.requests[peer.requests[0]] of SyncRequestType):
      raise newLoggedException(PeerError, "Peer sent us an invalid response to our SyncRequest.")

    #Void result types are used for DataMissing.
    when ResultType is void:
      #Verify the request wasn't for Peers, the only request to now allow DataMissing.
      if manager.requests[peer.requests[0]] of PeersSyncRequest:
        raise newLoggedException(PeerError, "Peer sent us an invalid response to our SyncRequest.")

    when not (ResultType is void):
      #Grab and cast the request.
      var request: SyncRequestType = cast[SyncRequestType](manager.requests[peer.requests[0]])

      #If it's a PeersSyncRequest, append to the pending peers list instead of completing the future.
      when SyncRequestType is PeersSyncRequest:
        try:
          for peerSuggestion in msg.message.parse():
            if not request.existing.contains(peerSuggestion.ip):
              request.pending.add((
                ip: (
                  $peerSuggestion.ip[0].fromBinary() & "." &
                  $peerSuggestion.ip[1].fromBinary() & "." &
                  $peerSuggestion.ip[2].fromBinary() & "." &
                  $peerSuggestion.ip[3].fromBinary()
                ),
                port: peerSuggestion.port
              ))
            request.existing.incl(peerSuggestion.ip)
        except ValueError as e:
          panic("Parsing peers raised a ValueError: " & e.msg)

        #Mark that this Peer completed.
        dec(request.remaining)

        #If this was the last peer, complete the future.
        if request.remaining == 0:
          try:
            request.result.complete(request.pending)
          except Exception as e:
            panic("Couldn't complete a Future: " & e.msg)

        #Delete the request from this Peer and return.
        peer.requests.delete(0)
        return
      #Complete the future.
      else:
        try:
          request.result.complete(msg.message.parse(request.check))
        except ValueError:
          raise newLoggedException(PeerError, "Peer sent us an unparsable response to our SyncRequest.")
        except Exception as e:
          panic("Couldn't complete a Future: " & e.msg)
  except KeyError as e:
    panic("Couldn't get a SyncRequest we confirmed we have: " & e.msg)

  #Delete the Request.
  manager.requests.del(peer.requests[0])
  peer.requests.delete(0)

#Handle a new connection.
proc handle*(
  manager: SyncManager,
  peer: Peer,
  tAddy: TransportAddress,
  handshake: Message = newMessage(MessageType.End)
) {.forceCheck: [], async.} =
  #Send our Syncing and get their Syncing.
  try:
    await peer.sendSync(newMessage(
      MessageType.Syncing,
      char(manager.protocol) &
      char(manager.network) &
      char(manager.services) &
      manager.port.toBinary(PORT_LEN) &
      manager.functions.merit.getTail().serialize()
    ))
  except SocketError:
    return
  except Exception as e:
    panic("Sync handshaking threw an Exception despite catching all thrown Exceptions: " & e.msg)

  var msg: Message = handshake
  if msg.content == MessageType.End:
    try:
      msg = await peer.recvSync()
    except SocketError:
      return
    except PeerError as e:
      peer.close(e.msg)
      return
    except Exception as e:
      panic("Sync handshaking threw an Exception despite catching all thrown Exceptions: " & e.msg)

  if msg.content == MessageType.Busy:
    peer.sync.safeClose("Server we connected to was busy.")
    try:
      for p in 0 ..< msg.message[0].fromBinary():
        var ip: string = msg.message[BYTE_LEN + (p * PEER_LEN) ..< BYTE_LEN + (p * PEER_LEN) + IP_LEN]
        asyncCheck manager.functions.network.connect(
          $(ip[0].fromBinary()) & "." & $(ip[1].fromBinary()) & "." & $(ip[2].fromBinary()) & "." & $(ip[3].fromBinary()),
          msg.message[BYTE_LEN + (p * PEER_LEN) + IP_LEN ..< BYTE_LEN + (p * PEER_LEN) + PEER_LEN].fromBinary()
        )
    except IndexError as e:
      panic("Extracting peers from a Busy message raised an IndexError: " & e.msg)
    except Exception as e:
      panic("Calling connect due to a Busy message raised despite not throwing anything: " & e.msg)
    return
  elif msg.content != MessageType.Syncing:
    peer.close("Peer didn't send Syncing.")
    return

  var shake: Handshake = msg.message.parseHandshake()
  if shake.protocol != manager.protocol:
    peer.close("Peer uses a different protocol.")
    return

  if shake.network != manager.network:
    peer.close("Peer uses a different network.")
    return

  #Create an artificial BlockTail message.
  msg = newMessage(MessageType.BlockchainTail, shake.hash)

  #Receive and handle messages forever.
  var res: Message
  while true:
    res = newMessage(MessageType.End)

    block thisMsg:
      case msg.content:
        of MessageType.Syncing:
          #Manually send the BlockchainTail now since adding the tail may create Sync Requests.
          try:
            await peer.sendSync(newMessage(
              MessageType.BlockchainTail,
              manager.functions.merit.getTail().serialize()
            ))
          except SocketError:
            return
          except Exception as e:
            panic("Failed to reply to a Sync request: " & e.msg)

          #Add the tail.
          var tail: Hash[256] = msg.message[5 ..< 37].toHash[:256]()

          try:
            asyncCheck manager.functions.merit.addBlockByHash(peer, tail)
          except Exception as e:
            panic("Adding a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

        of MessageType.BlockchainTail:
          #Get the tail.
          var tail: Hash[256] = msg.message[0 ..< 32].toHash[:256]()

          #Add the Block.
          try:
            asyncCheck manager.functions.merit.addBlockByHash(peer, tail)
          except Exception as e:
            panic("Adding a Block threw an Exception despite catching all thrown Exceptions: " & e.msg)

        of MessageType.PeersRequest:
          var peers: seq[Peer] = manager.peers.getPeers(msg.peer, server = true, sqrt = false)

          res = newMessage(MessageType.Peers, peers.len.toBinary(BYTE_LEN))
          for peer in peers:
            res.message &= peer.ip[0 ..< IP_LEN] & peer.port.toBinary(PORT_LEN)

        of MessageType.Peers:
          try:
            handleResponse[PeersSyncRequest, seq[tuple[ip: string, port: int]], void](
              manager,
              peer,
              msg,
              proc (
                serialization: string
              ): seq[tuple[ip: string, port: int]] {.forceCheck: [].} =
                result = newSeq[tuple[ip: string, port: int]](serialization[0].fromBinary())
                for p in 0 ..< result.len:
                  result[p] = (
                    ip: serialization[BYTE_LEN + (p * PEER_LEN) ..< BYTE_LEN + (p * PEER_LEN) + IP_LEN],
                    port: serialization[BYTE_LEN + (p * PEER_LEN) + IP_LEN ..< BYTE_LEN + (p * PEER_LEN) + PEER_LEN].fromBinary()
                  )
            )
          except ValueError as e:
            panic("Passing a function which can raise ValueError raised a ValueError: " & e.msg)
          except PeerError as e:
            peer.close(e.msg)
            return

        of MessageType.BlockListRequest:
          var
            list: string = ""
            last: Hash[256] = msg.message[BYTE_LEN ..< BYTE_LEN + HASH_LEN].toHash[:256]()
            i: int = -1

          try:
            while i < int(msg.message[0]):
              last = manager.functions.merit.getBlockHashBefore(last)
              list &= last.serialize()
              inc(i)
          except IndexError:
            discard

          if i == -1:
            res = newMessage(MessageType.DataMissing)
          else:
            res = newMessage(MessageType.BlockList, char(i) & list)

        of MessageType.BlockList:
          try:
            handleResponse[BlockListSyncRequest, seq[Hash[256]], bool](
              manager,
              peer,
              msg,
              proc (
                serialization: string,
                check: bool
              ): seq[Hash[256]] {.forceCheck: [].} =
                #Parse out the hashes.
                result = newSeq[Hash[256]](1 + int(serialization[0]))
                for i in 0 ..< result.len:
                  result[i] = msg.message[BYTE_LEN + (i * HASH_LEN) ..< BYTE_LEN + HASH_LEN + (i * HASH_LEN)].toHash[:256]()
            )
          except PeerError as e:
            peer.close(e.msg)
            return

        of MessageType.BlockHeaderRequest:
          try:
            res = newMessage(
              MessageType.BlockHeader,
              manager.functions.merit.getBlockByHash(msg.message.toHash[:256]()).header.serialize()
            )
          except IndexError:
            res = newMessage(MessageType.DataMissing)

        of MessageType.BlockBodyRequest:
          try:
            var requested: Block = manager.functions.merit.getBlockByHash(msg.message[0 ..< 32].toHash[:256]())
            res = newMessage(MessageType.BlockBody, requested.body.serialize(requested.header.sketchSalt, msg.message[32 ..< 36].fromBinary()))
          except ValueError as e:
            panic("Couldn't create a sketch for a BlockBody, despite being able to add it which means it has a valid sketch: " & e.msg)
          except IndexError:
            res = newMessage(MessageType.DataMissing)

        of MessageType.SketchHashesRequest:
          var requested: Block
          try:
            requested = manager.functions.merit.getBlockByHash(msg.message.toHash[:256]())
            res = newMessage(MessageType.SketchHashes, requested.body.packets.len.toBinary(INT_LEN))
            for packet in requested.body.packets:
              res.message &= sketchHash(requested.header.sketchSalt, packet).toBinary(SKETCH_HASH_LEN)
          except IndexError:
            res = newMessage(MessageType.DataMissing)

        of MessageType.SketchHashRequests:
          var requested: Block
          try:
            requested = manager.functions.merit.getBlockByHash(msg.message[0 ..< HASH_LEN].toHash[:256]())

            #Create a Table of the Sketch Hashes.
            var packets: Table[string, VerificationPacket] = initTable[string, VerificationPacket]()
            for packet in requested.body.packets:
              packets[sketchHash(requested.header.sketchSalt, packet).toBinary(SKETCH_HASH_LEN)] = packet

            for i in 0 ..< msg.message[HASH_LEN ..< HASH_LEN + INT_LEN].fromBinary():
              res = newMessage(
                MessageType.VerificationPacket,
                packets[msg.message[
                  HASH_LEN + INT_LEN + (i * SKETCH_HASH_LEN) ..<
                  HASH_LEN + INT_LEN + SKETCH_HASH_LEN + (i * SKETCH_HASH_LEN)
                ]].serialize()
              )

              try:
                await peer.sendSync(res)
              except SocketError:
                return
              except Exception as e:
                panic("Failed to reply to a Sync request: " & e.msg)

            res = newMessage(MessageType.End)
          except IndexError, KeyError:
            res = newMessage(MessageType.DataMissing)

        of MessageType.TransactionRequest:
          var tx: Transaction
          try:
            tx = manager.functions.transactions.getTransaction(msg.message.toHash[:256]())
            if tx of Mint:
              raise newLoggedException(IndexError, "TransactionRequest asked for a Mint.")

            var content: MessageType
            case tx:
              of Claim as _:
                content = MessageType.Claim
              of Send as _:
                content = MessageType.Send
              of Data as _:
                content = MessageType.Data
              else:
                panic("Responding with an unsupported Transaction type to a TransactionRequest.")

            res = newMessage(content, tx.serialize())
          except IndexError:
            res = newMessage(MessageType.DataMissing)

        of MessageType.DataMissing:
          try:
            handleResponse[SyncRequest, void, bool](
              manager,
              peer,
              msg,
              proc (
                serialization: string,
                check: bool
              ): void {.forceCheck: [].} =
                panic("Handling a DataMissing got to the parse function.")
            )
          except PeerError as e:
            peer.close(e.msg)
            return

        of MessageType.Claim:
          try:
            handleResponse[TransactionSyncRequest, Transaction, Hash[256]](
              manager,
              peer,
              msg,
              proc (
                serialization: string,
                check: Hash[256]
              ): Transaction {.forceCheck: [
                ValueError
              ].} =
                try:
                  result = serialization.parseClaim()
                except ValueError as e:
                  raise e

                if result.hash != check:
                  raise newLoggedException(ValueError, "Peer sent the wrong Transaction.")
            )
          except ValueError as e:
            panic("Passing a function which can raise ValueError raised a ValueError: " & e.msg)
          except PeerError as e:
            peer.close(e.msg)
            return

        of MessageType.Send:
          try:
            handleResponse[TransactionSyncRequest, Transaction, Hash[256]](
              manager,
              peer,
              msg,
              proc (
                serialization: string,
                check: Hash[256]
              ): Transaction {.forceCheck: [
                ValueError
              ].} =
                try:
                  result = serialization.parseSend(uint32(0))
                except ValueError as e:
                  raise e
                except Spam as e:
                  panic("Synced Transaction was identified as Spam: " & e.msg)

                if result.hash != check:
                  raise newLoggedException(ValueError, "Peer sent the wrong Transaction.")
            )
          except ValueError as e:
            panic("Passing a function which can raise ValueError raised a ValueError: " & e.msg)
          except PeerError as e:
            peer.close(e.msg)
            return

        of MessageType.Data:
          try:
            handleResponse[TransactionSyncRequest, Transaction, Hash[256]](
              manager,
              peer,
              msg,
              proc (
                serialization: string,
                check: Hash[256]
              ): Transaction {.forceCheck: [
                ValueError
              ].} =
                try:
                  result = serialization.parseData(uint32(0))
                except ValueError as e:
                  raise e
                except Spam as e:
                  panic("Synced Transaction was identified as Spam: " & e.msg)

                if result.hash != check:
                  raise newLoggedException(ValueError, "Peer sent the wrong Transaction.")
            )
          except ValueError as e:
            panic("Passing a function which can raise ValueError raised a ValueError: " & e.msg)
          except PeerError as e:
            peer.close(e.msg)
            return

        of MessageType.BlockHeader:
          try:
            handleResponse[BlockHeaderSyncRequest, BlockHeader, Hash[256]](
              manager,
              peer,
              msg,
              proc (
                serialization: string,
                check: Hash[256]
              ): BlockHeader {.forceCheck: [
                ValueError
              ].} =
                try:
                  result = parseBlockHeaderWithoutHashing(serialization)
                except ValueError as e:
                  raise e
            )
          except ValueError as e:
            panic("Passing a function which can raise ValueError raised a ValueError: " & e.msg)
          except PeerError as e:
            peer.close(e.msg)
            return

        of MessageType.BlockBody:
          try:
            handleResponse[BlockBodySyncRequest, SketchyBlockBody, Hash[256]](
              manager,
              peer,
              msg,
              proc (
                serialization: string,
                check: Hash[256]
              ): SketchyBlockBody {.forceCheck: [
                ValueError
              ].} =
                try:
                  result = serialization.parseBlockBody()
                except ValueError as e:
                  raise e

                if (
                  (result.data.elements.len == 0) and
                  (result.data.packetsContents == Hash[256]())
                ):
                  if check == Hash[256]():
                    return
                  raise newLoggedException(ValueError, "Peer sent the wrong BlockBody.")

                var elementsMerkle: Merkle = newMerkle()
                for elem in result.data.elements:
                  elementsMerkle.add(Blake256(elem.serializeContents()))

                if Blake256(result.data.packetsContents.serialize() & elementsMerkle.hash.serialize()) != check:
                  raise newLoggedException(ValueError, "Peer sent the wrong BlockBody.")
            )
          except ValueError as e:
            panic("Passing a function which can raise ValueError raised a ValueError: " & e.msg)
          except PeerError as e:
            peer.close(e.msg)
            return

        of MessageType.SketchHashes:
          try:
            handleResponse[SketchHashesSyncRequest, seq[uint64], Hash[256]](
              manager,
              peer,
              msg,
              proc (
                serialization: string,
                check: Hash[256]
              ): seq[uint64] {.forceCheck: [
                ValueError
              ].} =
                #Parse out the sketch hashes.
                result = newSeq[uint64](msg.message[0 ..< INT_LEN].fromBinary())
                for i in 0 ..< result.len:
                  result[i] = uint64(msg.message[INT_LEN + (i * SKETCH_HASH_LEN) ..< INT_LEN + SKETCH_HASH_LEN + (i * SKETCH_HASH_LEN)].fromBinary())

                #Verify the sketchCheck Merkle.
                try:
                  check.verifySketchCheck(result)
                except ValueError as e:
                  raise e
            )
          except ValueError as e:
            panic("Passing a function which can raise ValueError raised a ValueError: " & e.msg)
          except PeerError as e:
            peer.close(e.msg)
            return

        of MessageType.VerificationPacket:
          #Verify there's a Sync Request to check.
          if peer.requests.len == 0:
            peer.close("Peer sent a VerificationPacket when we have no open requests.")
            return

          #Verify the Request is still active.
          if not manager.requests.hasKey(peer.requests[0]):
            peer.requests.delete(0)
            break thisMsg

          var request: SketchHashSyncRequests
          try:
            #Verify the Request is a SketchHashSyncRequests.
            if not (manager.requests[peer.requests[0]] of SketchHashSyncRequests):
              peer.close("Peer responded with a VerificationPacket to a different SyncRequest.")
              return

            request = cast[SketchHashSyncRequests](manager.requests[peer.requests[0]])
          except KeyError as e:
            panic("Couldn't get a SyncRequest we confirmed we have: " & e.msg)

          #Receive the rest of the packets.
          var packets: seq[VerificationPacket] = newSeq[Verificationpacket](request.check.sketchHashes.len)

          #Parse and verify the initial packet.
          try:
            packets[0] = msg.message.parseVerificationPacket()
          except ValueError as e:
            peer.close(e.msg)
            return
          if sketchHash(request.check.salt, packets[0]) != request.check.sketchHashes[0]:
            peer.close("Peer sent the wrong VerificationPacket.")
            return

          var i: int = 1
          while i < packets.len:
            try:
              msg = await peer.recvSync()
            except SocketError:
              return
            except PeerError as e:
              peer.close(e.msg)
              return
            except Exception as e:
              panic("Receiving a new message threw an Exception despite catching all thrown Exceptions: " & e.msg)

            if msg.content == MessageType.DataMissing:
              break

            #Parse and verify the packet.
            try:
              packets[i] = msg.message.parseVerificationPacket()
            except ValueError as e:
              peer.close(e.msg)
              return
            if sketchHash(request.check.salt, packets[i]) != request.check.sketchHashes[i]:
              peer.close("Peer sent the wrong VerificationPacket.")
              return

            inc(i)

          #Verify we received every packet.
          if i != request.check.sketchHashes.len:
            break thisMsg

          #Complete the future, if it's still incomplete.
          if not request.result.finished:
            try:
              request.result.complete(packets)
            except Exception as e:
              panic("Couldn't complete a Future: " & e.msg)

          #Delete the Request.
          manager.requests.del(peer.requests[0])
          peer.requests.delete(0)

        else:
          peer.close("Peer sent an invalid Message type.")
          return

      #Reply with the response, if there is one.
      if res.content != MessageType.End:
        try:
          await peer.sendSync(res)
        except SocketError:
          return
        except Exception as e:
          panic("Failed to reply to a Sync request: " & e.msg)

    #Receive the next message.
    try:
      msg = await peer.recvSync()
    except SocketError:
      return
    except PeerError as e:
      peer.close(e.msg)
      return
    except Exception as e:
      panic("Receiving a new message threw an Exception despite catching all thrown Exceptions: " & e.msg)
