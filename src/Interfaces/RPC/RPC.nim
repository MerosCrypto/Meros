import chronos

import ../../lib/Errors

import ../../objects/[ConfigObj, GlobalFunctionBoxObj]

import objects/RPCObj
export RPC

import Modules/[
  TransactionsModule,
  ConsensusModule,
  MeritModule,
  PersonalModule,
  NetworkModule
]

proc newRPC*(
  functions: GlobalFunctionBox,
  toRPC: ptr Channel[JSONNode],
  toGUI: ptr Channel[JSONNode]
): RPC {.forceCheck: [].} =
  newRPCObj(
    merge(
      (prefix: "transactions_", rpc: TransactionsModule.module(functions)),
      (prefix: "consensus_",  rpc: ConsensusModule.module(functions)),
      (prefix: "merit_",    rpc: MeritModule.module(functions)),
      (prefix: "personal_",   rpc: PersonalModule.module(functions)),
      (prefix: "network_",    rpc: NetworkModule.module(functions))
    ),
    functions.system.quit,
    toRPC,
    toGUI
  )

#Add an error response to an existing JSONNode.
proc error(
  res: JSONNode,
  code: int,
  msg: string,
  data: JSONNode = nil
) {.forceCheck: [].} =
  res["error"] = %* {
    "code": code,
    "message": msg
  }

  try:
    if not data.isNil:
      res["error"]["data"] = data
  except KeyError as e:
    panic("Couldn't set an error's data field, despite just creating the data: " & e.msg)

#Create a new error response.
proc newError(
  id: JSONNode,
  code: int,
  msg: string,
  data: JSONNode = nil
): JSONNode {.forceCheck: [].} =
  result = %* {
    "jsonrpc": "2.0",
    "id": id
  }
  error(result, code,msg, data)

#Handle a request and store the result in res.
proc handle*(
  rpc: RPC,
  req: JSONNode,
  res: ref JSONNode,
  reply: proc (
    res: JSONNode
  ): Future[void] {.gcsafe.}
) {.forceCheck: [], async.} =
  #Verify the version.
  try:
    if (not req.hasKey("jsonrpc")) or (req["jsonrpc"].getStr() != "2.0"):
      error(res[], -32600, "Invalid Request")
      return
  except KeyError as e:
    panic("Couldn't check the RPC version despite confirming its existence: " & e.msg)

  #Verify the method exists.
  try:
    if (not req.hasKey("method")) or (req["method"].kind != JString):
      error(res[], -32600, "Invalid Request")
      return
  except KeyError as e:
    panic("Couldn't check the RPC method despite confirming its existence: " & e.msg)

  #Add params if it was omitted.
  if (not req.hasKey("params")):
    req["params"] = % []

  #Make sure the param were an array.
  try:
    if req["params"].kind != JArray:
      error(res[], -32600, "Invalid Request")
      return
  except KeyError as e:
    panic("Couldn't check the RPC params despite confirming their existence: " & e.msg)

  #Override for system_quit.
  try:
    if req["method"].getStr() == "system_quit":
      res[]["result"] = % true
      try:
        await reply(res[])
      except Exception as e:
        panic("Couldn't call reply, despite catching all naturally thrown Exceptions: " & e.msg)
      rpc.quit()
  except KeyError as e:
    panic("Couldn't get the RPC method despite confirming its existence: " & e.msg)

  try:
    #Make sure the method exists.
    if not rpc.functions.hasKey(req["method"].getStr()):
      error(res[], -32601, "Method not found")
      return

    #Call the method.
    await rpc.functions[req["method"].getStr()](res[], req["params"])

  #Handle KeyErrors.
  except KeyError as e:
    panic("Couldn't call a RPC method despite confirming its existence: " & e.msg)

  #If there was an invalid parameter, create the proper error response.
  except ParamError:
    try:
      res[] = newError(req["id"], -32602, "Invalid params")
    except KeyError as e:
      panic("Couldn't get the ID despite guaranteeing its existence: " & e.msg)
    return

  #If a parameter had an invalid value, create the proper response.
  except JSONRPCError as e:
    try:
      res[] = newError(req["id"], e.code, e.msg, e.data)
    except KeyError as e:
      panic("Couldn't get the ID despite guaranteeing its existence: " & e.msg)
    return

  #If we panic, make sure it bubbles up.
  except AssertionError as e:
    panic("RPC caused a panic: " & e.msg)

  #Else, respond that we had an internal error.
  #Generally, we would panic here, yet the amount of custom data that can be entered makes that a worrysome prospect.
  except Exception:
    try:
      res[] = newError(req["id"], -32603, "Internal error")
    except KeyError as e:
      panic("Couldn't get the ID despite guaranteeing its existence: " & e.msg)
    return

  #If the result isn't null and has no result field, provide a result field of true.
  if (not res[].isNil) and (not res[].hasKey("result")):
    res[]["result"] = % true

#Handle a request and return the result.
proc handle*(
  rpc: RPC,
  req: JSONNode,
  reply: proc (
    res: JSONNode
  ): Future[void] {.gcsafe.}
): Future[ref JSONNode] {.forceCheck: [], async.} =
  #Init the result.
  result = new(ref JSONNode)

  #If this is a singular request...
  if req.kind == JObject:
    #Add an ID if it was omitted.
    if not req.hasKey("id"):
      req["id"] = % newJNull()

    #Create the response.
    try:
      result[] = %* {
        "jsonrpc": "2.0",
        "id": req["id"]
      }
    except KeyError as e:
      panic("Couldn't get the ID despite guaranteeing its existence: " & e.msg)

    #Handle it.
    try:
      await handle(rpc, req, result, reply)
    except Exception as e:
      panic("Couldn't handle the request (JSON; return res), despite catching all naturally thrown Exceptions: " & e.msg)

  #If this was a batch request...
  elif req.kind == JArray:
    #Prepare the result.
    var results: ref JSONNode = new(ref JSONNode)
    results[] = newJArray()

    #Iterate over each request.
    for reqElem in req:
      #Add an ID if it was omitted.
      if not reqElem.hasKey("id"):
        reqElem["id"] = % nil

      #Prepare this specific result.
      try:
        result[] = %* {
          "jsonrpc": "2.0",
          "id": reqElem["id"]
        }
      except KeyError as e:
        panic("Couldn't get the ID despite guaranteeing its existence: " & e.msg)

      #Check the request's type.
      try:
        if reqElem.kind != JObject:
          results[].add(newError(reqElem["id"], -32600, "Invalid Request"))
          continue
      except KeyError as e:
        panic("Couldn't get the ID despite guaranteeing its existence: " & e.msg)

      #Handle it.
      try:
        await handle(
          rpc,
          reqElem,
          result,
          proc (
            res: JSONNode
          ) {.forceCheck: [], async.} =
            results[].add(res)
            try:
              await reply(results[])
            except Exception as e:
              panic("Couldn't call reply, despite catching all naturally thrown Exceptions: " & e.msg)
        )
      except Exception as e:
        panic("Couldn't handle the request (batch JSON; return res), despite catching all naturally thrown Exceptions: " & e.msg)

      #If there was a result, add it.
      if not result[].isNil:
        results[].add(result[])

    #Set result to results.
    result = results

  else:
    error(result[], -32600, "Invalid Request")
    return

#Handle a string and return a string.
proc handle*(
  rpc: RPC,
  reqStr: string,
  reply: proc (
    res: string
  ): Future[void] {.gcsafe.}
): Future[string] {.forceCheck: [], async.} =
  var
    req: JSONNode
    res: ref JSONNode

  #Parse the request.
  try:
    req = parseJSON(reqStr)
  except Exception:
    return $newError(newJNull(), -32700, "Parse error")

  #Handle it.
  try:
    res = await rpc.handle(
      req,
      proc (
        res: JSONNode
      ) {.forceCheck: [], async.} =
        try:
          await reply($res)
        except Exception as e:
          panic("Couldn't call reply, despite catching all naturally thrown Exceptions: " & e.msg)
    )
  except Exception as e:
    panic("Couldn't handle the request (string), despite catching all naturally thrown Exceptions: " & e.msg)

  #Return the string.
  if res[].isNil:
    result = ""
  else:
    result = $res[]

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
    var res: ref JSONNode
    try:
      res = await rpc.handle(
        data.msg,
        proc (
          replyArg: JSONNode
        ) {.forceCheck: [], async.} =
          try:
            rpc.toGUI[].send(replyArg)
          except DeadThreadError as e:
            panic("Couldn't send to a dead thread: " & e.msg)
          except Exception as e:
            panic("Sending over a channel threw an Exception: " & e.msg)
      )
    except Exception as e:
      panic("Couldn't handle the request from the GUI, despite catching all naturally thrown Exceptions: " & e.msg)

    try:
      rpc.toGUI[].send(res[])
    except DeadThreadError as e:
      panic("Couldn't send to a dead thread: " & e.msg)
    except Exception as e:
      panic("Sending over a channel threw an Exception: " & e.msg)

#Create a function to handle a connection.
proc handle(
  rpc: RPC
): proc (
  server: StreamServer,
  socket: StreamTransport
): Future[void] {.gcsafe.} {.inline, forceCheck: [].} =
  result = proc (
    server: StreamServer,
    socket: StreamTransport
  ) {.forceCheck: [], async.} =
    #Handle the client.
    while not socket.closed():
      #Read in a message.
      var
        data: string = ""
        counter: int = 0
        oldLen: int = 1
      while true:
        try:
          data &= cast[string](await socket.read(1))
        except Exception:
          try:
            socket.close()
          except Exception:
            discard
          return

        if data.len != oldLen:
          try:
            socket.close()
          except Exception:
            discard
          return
        inc(oldLen)

        if data[^1] == data[0]:
          inc(counter)
        elif (data[^1] == ']') and (data[0] == '['):
          dec(counter)
        elif (data[^1] == '}') and (data[0] == '{'):
          dec(counter)
        if counter == 0:
          break

      #Handle the message.
      var res: string
      try:
        res = await rpc.handle(
          data,
          proc (
            replyArg: string
          ) {.forceCheck: [], async.} =
            try:
              if (await socket.write(replyArg)) != replyArg.len:
                raise newException(Exception, "")
            except Exception:
              try:
                socket.close()
              except Exception:
                discard
              return
        )
      except Exception as e:
        panic("RPC's handle threw an Exception despite not naturally throwing anything: " & e.msg)

      try:
        if (await socket.write(res)) != res.len:
          raise newException(Exception, "")
      except Exception:
        try:
          socket.close()
        except Exception:
          discard
        return

#Start up the RPC's server socket.
proc listen*(
  rpc: RPC,
  config: Config
) {.forceCheck: [], async.} =
  #Create the server.
  try:
    rpc.server = createStreamServer(initTAddress("0.0.0.0", config.rpcPort), handle(rpc), {ReuseAddr})
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
