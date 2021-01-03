import chronos

import ../../../lib/Errors

import ../../../objects/GlobalFunctionBoxObj

import ../objects/RPCObj

#Default network port.
const DEFAULT_PORT {.intdefine.}: int = 5132

proc module*(
  functions: GlobalFunctionBox
): RPCFunctions {.forceCheck: [].} =
  try:
    newRPCFunctions:
      proc connect(
        ip: string,
        port: int = DEFAULT_PORT
      ): bool {.requireAuth, forceCheck: [
        ValueError
      ], async.} =
        result = true
        try:
          await functions.network.connect(address, port)
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
        _block: Option[Hash[256]] = none(Hash[256])
      ): bool {.forceCheck: [
        ParamsError,
        JSONRPCError
      ].} =
        result = true

        if transaction.isSome:
          var tx: Transaction
          try:
            tx = functions.transactions.getTransaction(transaction.unsafeGet())
          except IndexError:
            raise newJSONRPCError(IndexError, "Transaction not found")
          case tx:
            of Mint as _:
              discard
            of Claim as claim:
              functions.network.broadcast(MessageType.Claim, tx.serialize())
            of Send as send:
              functions.network.broadcast(MessageType.Send, tx.serialize())
            of Data as data:
              functions.network.broadcast(MessageType.Data, tx.serialize())

        if _block.isSome():
          try:
            functions.network.broadcast(
              MessageType.BlockHeader,
              functions.merit.getBlock(_block.getUnsafe()).header.serialize()
            )
          except IndexError:
            raise newJSONRPCError(IndexError, "Block not found")

  except Exception as e:
    panic("Couldn't create the Network Module: " & e.msg)
