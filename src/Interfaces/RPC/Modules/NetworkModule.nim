import options
import strutils
import json

import chronos

import ../../../lib/Errors
import ../../../lib/Hash

import ../../../Database/Transactions/Transaction
import ../../../Database/Merit/BlockHeader

import ../../../Network/objects/MessageObj
import ../../../Network/Serialize/Transactions/[SerializeClaim, SerializeSend, SerializeData]
import ../../../Network/Serialize/Merit/SerializeBlockHeader

import ../../../objects/GlobalFunctionBoxObj

import ../objects/RPCObj

#Default network port.
const DEFAULT_PORT {.intdefine.}: int = 5132

proc module*(
  functions: GlobalFunctionBox
): RPCHandle {.forceCheck: [].} =
  try:
    result = newRPCHandle:
      proc connect(
        address: string,
        port: Option[int] = some(DEFAULT_PORT)
      ) {.requireAuth, forceCheck: [], async.} =
        try:
          await functions.network.connect(address, port.unsafeGet())
        except Exception as e:
          panic("MainNetwork's connect threw an Exception despite not naturally throwing anything: " & e.msg)

      proc getPeers(): JSONNode {.forceCheck: [].} =
        result = % []

        for client in functions.network.getPeers():
          result.add(%* {
            "ip": (
              $int(client.ip[0]) & "." &
              $int(client.ip[1]) & "." &
              $int(client.ip[2]) & "." &
              $int(client.ip[3])
            ),
            "server": client.server
          })
          if client.server:
            result[result.len - 1]["port"] = % client.port

      proc broadcast(
        transaction: Option[Hash[256]] = none(Hash[256]),
        block_JSON: Option[Hash[256]] = none(Hash[256])
      ) {.forceCheck: [
        JSONRPCError
      ].} =
        if transaction.isSome:
          var tx: Transaction
          try:
            tx = functions.transactions.getTransaction(transaction.unsafeGet())
          except IndexError:
            raise newJSONRPCError(IndexError, "Transaction not found")
          case tx:
            of Mint as _:
              raise newJSONRPCError(ValueError, "Transaction is a Mint")
            of Claim as _:
              functions.network.broadcast(MessageType.Claim, tx.serialize())
            of Send as _:
              functions.network.broadcast(MessageType.Send, tx.serialize())
            of Data as _:
              functions.network.broadcast(MessageType.Data, tx.serialize())

        if block_JSON.isSome():
          try:
            let header: BlockHeader = functions.merit.getBlockByHash(block_JSON.unsafeGet()).header
            if header.hash == functions.merit.getBlockByNonce(0).header.hash:
              raise newJSONRPCError(ValueError, "Block is the genesis Block")
            functions.network.broadcast(MessageType.BlockHeader, header.serialize())
          except IndexError:
            raise newJSONRPCError(IndexError, "Block not found")

  except Exception as e:
    panic("Couldn't create the Network Module: " & e.msg)
