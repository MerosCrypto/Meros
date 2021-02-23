import strutils
import json

import chronos

import ../../lib/Errors

import ../../objects/[ConfigObj, GlobalFunctionBoxObj]

import objects/RPCObj
export RPCObj.RPC

import Modules/[
  SystemModule,
  TransactionsModule,
  ConsensusModule,
  MeritModule,
  PersonalModule,
  NetworkModule
]

#Create a new error response.
proc newError(
  id: JSONNode,
  code: int,
  msg: string,
  data: JSONNode = nil
): JSONNode {.forceCheck: [].} =
  result = %* {
    "jsonrpc": "2.0",
    "id": id,
    "error": {
      "code": code,
      #These shouldn't have periods, as exemplified by the spec's lack of periods on official messages.
      #Meros follows that standard, yet its own exceptions use periods.
      #That means quoted exceptions will create a message ending with a period.
      #Hence the if statement.
      "message": if msg[^1] == '.': msg[0 ..< msg.len - 1] else: msg
    }
  }

  try:
    if not data.isNil:
      result["error"]["data"] = data
  except KeyError as e:
    panic("Couldn't set an error's data field, despite just creating the error: " & e.msg)

proc newRPC*(
  functions: GlobalFunctionBox,
  toRPC: ptr Channel[JSONNode],
  toGUI: ptr Channel[JSONNode]
): RPC {.forceCheck: [].} =
  var modules: seq[tuple[prefix: string, handle: RPCHandle]] = @[
    (prefix: "system_",       handle: SystemModule.module(functions)),
    (prefix: "transactions_", handle: TransactionsModule.module(functions)),
    (prefix: "consensus_",    handle: ConsensusModule.module(functions)),
    (prefix: "merit_",        handle: MeritModule.module(functions)),
    (prefix: "personal_",     handle: PersonalModule.module(functions)),
    (prefix: "network_",      handle: NetworkModule.module(functions))
  ]

  proc createHandler(): RPCHandle {.forceCheck: [].} =
    result = proc (
      req: JSONNode,
      reply: OuterRPCReplyFunction,
      authed: bool
    ): Future[void] {.forceCheck: [], async.} =
      #If this doesn't have an ID field, error. It's either an invalid request or notification.
      if not req.hasKey("id"):
        try:
          await reply(newError(newJNull(), -32603, "Internal error", %* {
            "reason": "Batch requests aren't supported"
          }))
          return
        except Exception as e:
          panic("Couldn't call reply about an Internal Error due to an Exception despite reply not naturally throwing anything: " & e.msg)

      #Provide a params value if one wasn't supplied, as it can be omitted.
      if not req.hasKey("params"):
        req["params"] = newJObject()

      #Check the request as a whole.
      try:
        if not (
          #Invalid version string.
          req.hasKey("jsonrpc") and (req["jsonrpc"].kind == JString) and (req["jsonrpc"].getStr() == "2.0") and
          #Invalid ID type.
          req.hasKey("id") and (
            (req["id"].kind == JString) or
            (req["id"].kind == JInt) or
            (req["id"].kind == JFloat) or
            (req["id"].kind == JNull)
          ) and
          #Technically invalid method field.
          req.hasKey("method") and (req["method"].kind == JString) and
          #Unstructured parameters.
          ((not req.hasKey("params")) or ((req["params"].kind == JArray) or (req["params"].kind == JObject)))
        ):
          try:
            await reply(newError(newJNull(), -32600, "Invalid Request"))
          except Exception as e:
            panic("Couldn't call reply about a Invalid Request due to an Exception despite reply not naturally throwing anything: " & e.msg)
          return
      except KeyError as e:
        panic("Couldn't get a RPC request's field despite confirming its existence: " & e.msg)

      #Supply params if they were omitted.
      if not req.hasKey("params"):
        req["params"] = newJObject()

      #While array parameters are technically valid, they aren't used by Meros.
      try:
        if req["params"].kind != JObject:
          try:
            await reply(newError(req["id"], -32602, "Invalid params"))
            return
          except KeyError as e:
            panic("Couldn't get the ID of the request despite confirming its existence: " & e.msg)
          except Exception as e:
            panic("Couldn't call reply about array params due to an Exception despite reply not naturally throwing anything: " & e.msg)
      except KeyError as e:
        panic("Couldn't get a RPC request's params field despite confirming its existence: " & e.msg)

      #Check for extra fields.
      #While we could let these slide, there isn't any good reason to allow them.
      if req.len != 4:
        try:
          await reply(newError(req["id"], -32600, "Invalid Request", %* {
            "reason": "Additional fields provided"
          }))
          return
        except KeyError as e:
          panic("Couldn't get the ID of the request despite confirming its existence: " & e.msg)
        except Exception as e:
          panic("Couldn't call reply about additional fields due to an Exception despite reply not naturally throwing anything: " & e.msg)

      var methodStr: string
      try:
        methodStr = req["method"].getStr()
      except KeyError as e:
        panic("Couldn't get the ID of the request despite confirming its existence: " & e.msg)

      #Find the matching RPC module and pass it off.
      var replied: bool = false
      for rpc in modules:
        if methodStr.startsWith(rpc.prefix):
          #Remove the prefix so only the method is returned.
          req["method"] = % methodStr[rpc.prefix.len ..< methodStr.len]

          #This has no raises pragma and should only raise ParamError/JSONRPCError.
          #That said, we also have to bubble up AssertionErrors and handle Exceptions.
          #There may also be a KeyError floating...
          try:
            await rpc.handle(req, reply, authed)
          #Not authorized.
          except RPCAuthorizationError:
            await reply(false)
          #If there was an invalid parameter, create the proper error response.
          except ParamError:
            try:
              await reply(newError(req["id"], -32602, "Invalid params"))
            except KeyError as e:
              panic("Couldn't get the ID despite guaranteeing its existence: " & e.msg)
            except Exception as e:
              panic("Couldn't call reply about a ParamError due to an Exception despite reply not naturally throwing anything: " & e.msg)

          #If there was an invalid value, create the proper response.
          except JSONRPCError as e:
            try:
              await reply(newError(req["id"], e.code, e.msg, e.data))
            except KeyError as e:
              panic("Couldn't get the ID despite guaranteeing its existence: " & e.msg)
            except Exception as e:
              panic("Couldn't call reply about a JSONRPCError due to an Exception despite reply not naturally throwing anything: " & e.msg)

          #If we panic, make sure it bubbles up.
          except AssertionError as e:
            panic("RPC caused a panic: " & e.msg)

          #If we hit a raw Exception, likely from the async runtime, panic.
          except Exception as e:
            panic("Raw Exception from the RPC, which may be something OTHER than async: " & e.msg)

          replied = true
          break

      if not replied:
        try:
          await reply(newError(req["id"], -32601, "Method not found"))
        except Exception as e:
          panic("Couldn't call reply about the method not being found due to an Exception despite reply not naturally throwing anything: " & e.msg)

  result = RPC(
    handle: createHandler(),
    toRPC: toRPC,
    toGUI: toGUI,

    alive: true
  )

#Start up the RPC's connection to the GUI.
proc start*(
  rpc: RPC
) {.forceCheck: [], async.} =
  while rpc.alive:
    #Allow other async code to execute.
    try:
      await sleepAsync(milliseconds(1))
    except Exception as e:
      panic("Couldn't sleep for 1ms before checking the GUI->RPC channel for data: " & e.msg)

    #Try to get a message from the GUI.
    var data: tuple[
      dataAvailable: bool,
      msg: JSONNode
    ]
    try:
      data = rpc.toRPC[].tryRecv()
    except ValueError as e:
      panic("Couldn't read from the channel using tryRecv due to a ValueError: " & e.msg)
    except Exception as e:
      panic("Couldn't read from the channel using tryRecv due to an Exception: " & e.msg)

    #If there's no data, continue.
    if not data.dataAvailable:
      continue

    #Handle the request.
    try:
      #Can't directly inline due to an AST gen bug.
      let rpcFuture: Future[void] = rpc.handle(
        data.msg,
        proc (
          reply: bool or JSONNode
        ) {.forceCheck: [], async.} =
          when reply is bool:
            panic("GUI was told it's unauthorized to make RPC calls.")
          else:
            try:
              rpc.toGUI[].send(reply)
            except DeadThreadError as e:
              panic("Couldn't send to a dead thread: " & e.msg)
            except Exception as e:
              panic("Sending over a channel threw an Exception: " & e.msg)
        , true
      )
      await rpcFuture
    except Exception as e:
      panic("Couldn't handle the request from the GUI, despite catching all naturally thrown Exceptions: " & e.msg)

#Create a function to handle a connection.
proc createSocketHandler(
  rpc: RPC
): proc (
  server: StreamServer,
  socket: StreamTransport
): Future[void] {.gcsafe.} {.inline, forceCheck: [].} =
  result = proc (
    server: StreamServer,
    socket: StreamTransport
  ) {.forceCheck: [], async.} =
    #Authed or not.
    #True while we have yet to set up an auth method.
    var authed: bool = true

    #Handle the client.
    while not socket.closed():
      #Read in a message.
      let body: string
      try:
        body = await socket.readHTTP()
        if body == "":
          continue
      except Exception as e:
        panic("readHTTP threw an error despite not naturally throwing anything: " & e.msg)

      #Handle the message.
      var parsedData: JSONNode
      try:
        parsedData = parseJSON(body)
      except Exception:
        try:
          await socket.writeHTTP($(newError(newJNull(), -32700, "Parse error")))
          return
        except Exception as e:
          logWarn "Couldn't respond to RPC socket client who sent invalid JSON", reason = e.msg
          try:
            socket.close()
          except Exception:
            discard
          return

      try:
        #See above instance for clarification.
        let rpcFuture: Future[void] = rpc.handle(
          parsedData,
          proc (
            replyArg: bool or JSONNode
          ) {.forceCheck: [], async.} =
            when replyArg is bool:
              await socket.unauthorized()
            else:
              try:
                await socket.writeHTTP($replyArg)
              except Exception as e:
                logWarn "Couldn't respond to RPC socket client", reason = e.msg
                try:
                  socket.close()
                except Exception:
                  discard
                return
          , authed
        )
        await rpcFuture
      except Exception as e:
        panic("RPC's handle threw an Exception despite not naturally throwing anything: " & e.msg)

#Start up the RPC's server socket.
proc listen*(
  rpc: RPC,
  config: Config
) {.forceCheck: [], async.} =
  #Create the server.
  try:
    rpc.server = createStreamServer(initTAddress("0.0.0.0", config.rpcPort), createSocketHandler(rpc), {ReuseAddr})
  except OSError as e:
    panic("Couldn't create the RPC server due to an OSError: " & e.msg)
  except TransportAddressError as e:
    panic("Couldn't create the RPC server due to an invalid address to listen on: " & e.msg)
  except Exception as e:
    panic("Couldn't create the RPC server due to an Exception: " & e.msg)

  #Start listening.
  try:
    rpc.server.start()
  except OSError as e:
    panic("Couldn't start listening due to an OSError: " & e.msg)
  except TransportOSError as e:
    panic("Couldn't start listening due to an TransportOSError: " & e.msg)
  except Exception as e:
    panic("Couldn't start listening due to an Exception: " & e.msg)

  #Don't return until the server closes.
  try:
    await rpc.server.join()
  except Exception as e:
    panic("Couldn't join the server with this async function: " & e.msg)

#Shutdown.
proc shutdown*(
  rpc: RPC
) {.forceCheck: [].} =
  #Close the server socket, if it exists.
  if not rpc.server.isNil:
    try:
      rpc.server.close()
    except Exception:
      discard

  #Set alive to false.
  rpc.alive = false
