#Errors lib.
import ../../lib/Errors

#Config object.
import ../../objects/ConfigObj

#GlobalFunctionBox object.
import ../../objects/GlobalFunctionBoxObj

#RPC object.
import objects/RPCObj
export RPCObj.RPC

#RPC modules.
import Modules/TransactionsModule
import Modules/ConsensusModule
import Modules/MeritModule
import Modules/PersonalModule
import Modules/NetworkModule

#Networking standard lib.
import asyncnet

#Constructor.
proc newRPC*(
    functions: GlobalFunctionBox,
    toRPC: ptr Channel[JSONNode],
    toGUI: ptr Channel[JSONNode]
): RPC {.forceCheck: [].} =
    newRPCObj(
        merge(
            (prefix: "transactions_", rpc: TransactionsModule.module(functions)),
            (prefix: "consensus_",    rpc: ConsensusModule.module(functions)),
            (prefix: "merit_",        rpc: MeritModule.module(functions)),
            (prefix: "personal_",     rpc: PersonalModule.module(functions)),
            (prefix: "network_",      rpc: NetworkModule.module(functions))
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
        doAssert(false, "Couldn't set an error's data field, despite just creating the data: " & e.msg)

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
    ): Future[void]
) {.forceCheck: [], async.} =
    #Verify the version.
    try:
        if (not req.hasKey("jsonrpc")) or (req["jsonrpc"].getStr() != "2.0"):
            error(res[], -32600, "Invalid Request")
            return
    except KeyError as e:
        doAssert(false, "Couldn't check the RPC version despite confirming its existence: " & e.msg)

    #Verify the method exists.
    try:
        if (not req.hasKey("method")) or (req["method"].kind != JString):
            error(res[], -32600, "Invalid Request")
            return
    except KeyError as e:
        doAssert(false, "Couldn't check the RPC method despite confirming its existence: " & e.msg)

    #Add params if it was omitted.
    if (not req.hasKey("params")):
        req["params"] = % []

    #Make sure the param were an array.
    try:
        if req["params"].kind != JArray:
            error(res[], -32600, "Invalid Request")
            return
    except KeyError as e:
        doAssert(false, "Couldn't check the RPC params despite confirming their existence: " & e.msg)

    #Override for system_quit.
    try:
        if req["method"].getStr() == "system_quit":
            res[]["result"] = % true
            try:
                await reply(res[])
            except Exception as e:
                doAssert(false, "Couldn't call reply, despite catching all naturally thrown Exceptions: " & e.msg)
            rpc.quit()
    except KeyError as e:
        doAssert(false, "Couldn't get the RPC method despite confirming its existence: " & e.msg)

    try:
        #Make sure the method exists.
        if not rpc.functions.hasKey(req["method"].getStr()):
            error(res[], -32601, "Method not found")
            return

        #Call the method.
        await rpc.functions[req["method"].getStr()](res[], req["params"])

    #Handle KeyErrors.
    except KeyError as e:
        doAssert(false, "Couldn't call a RPC method despite confirming its existence: " & e.msg)

    #If there was an invalid parameter, create the proper error response.
    except ParamError:
        try:
            res[] = newError(req["id"], -32602, "Invalid params")
        except KeyError as e:
            doAssert(false, "Couldn't get the ID despite guaranteeing its existence: " & e.msg)
        return

    #If a parameter had an invalid value, create the proper response.
    except JSONRPCError as e:
        try:
            res[] = newError(req["id"], e.code, e.msg, e.data)
        except KeyError as e:
            doAssert(false, "Couldn't get the ID despite guaranteeing its existence: " & e.msg)
        return

    #If we doAssert(false), make sure it bubbles up.
    except AssertionError as e:
        doAssert(false, "RPC caused a doAssert(false): " & e.msg)

    #Else, respond that we had an internal error.
    #Generally, we would doAssert(false) here, yet the amount of custom data that can be entered makes that a worrysome prospect.
    except Exception:
        try:
            res[] = newError(req["id"], -32603, "Internal error")
        except KeyError as e:
            doAssert(false, "Couldn't get the ID despite guaranteeing its existence: " & e.msg)
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
    ): Future[void]
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
            doAssert(false, "Couldn't get the ID despite guaranteeing its existence: " & e.msg)

        #Handle it.
        try:
            await handle(rpc, req, result, reply)
        except Exception as e:
            doAssert(false, "Couldn't handle the request (JSON; return res), despite catching all naturally thrown Exceptions: " & e.msg)

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
                doAssert(false, "Couldn't get the ID despite guaranteeing its existence: " & e.msg)

            #Check the request's type.
            try:
                if reqElem.kind != JObject:
                    results[].add(newError(reqElem["id"], -32600, "Invalid Request"))
                    continue
            except KeyError as e:
                doAssert(false, "Couldn't get the ID despite guaranteeing its existence: " & e.msg)

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
                            doAssert(false, "Couldn't call reply, despite catching all naturally thrown Exceptions: " & e.msg)
                )
            except Exception as e:
                doAssert(false, "Couldn't handle the request (batch JSON; return res), despite catching all naturally thrown Exceptions: " & e.msg)

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
    ): Future[void]
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
                    doAssert(false, "Couldn't call reply, despite catching all naturally thrown Exceptions: " & e.msg)
        )
    except Exception as e:
        doAssert(false, "Couldn't handle the request (string), despite catching all naturally thrown Exceptions: " & e.msg)

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
            await sleepAsync(1)
        except Exception as e:
            doAssert(false, "Couldn't sleep for 1ms before checking the GUI->RPC channel for data: " & e.msg)

        #Try to get a message from the GUI.
        var data: tuple[
            dataAvailable: bool,
            msg: JSONNode
        ]
        try:
            data = rpc.toRPC[].tryRecv()
        except ValueError as e:
            doAssert(false, "Couldn't read from the channel using tryRecv due to a ValueError: " & e.msg)
        except Exception as e:
            doAssert(false, "Couldn't read from the channel using tryRecv due to an Exception: " & e.msg)

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
                        doAssert(false, "Couldn't send to a dead thread: " & e.msg)
                    except Exception as e:
                        doAssert(false, "Sending over a channel threw an Exception: " & e.msg)
            )
        except Exception as e:
            doAssert(false, "Couldn't handle the request from the GUI, despite catching all naturally thrown Exceptions: " & e.msg)

        try:
            rpc.toGUI[].send(res[])
        except DeadThreadError as e:
            doAssert(false, "Couldn't send to a dead thread: " & e.msg)
        except Exception as e:
            doAssert(false, "Sending over a channel threw an Exception: " & e.msg)

#Handle a connection.
proc handle(
    rpc: RPC,
    client: AsyncSocket
) {.forceCheck: [], async.} =
    #Handle the client.
    while not client.isClosed():
        #Read in a message.
        var
            data: string = ""
            counter: int = 0
            oldLen: int = 1
        while true:
            try:
                data &= await client.recv(1)
            except Exception:
                try:
                    client.close()
                except Exception:
                    discard
                return

            if data.len != oldLen:
                try:
                    client.close()
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
                        await client.send(replyArg)
                    except Exception:
                        try:
                            client.close()
                        except Exception:
                            discard
                        return
            )
        except Exception as e:
            doAssert(false, "RPC's handle threw an Exception despite not naturally throwing anything: " & e.msg)

        try:
            await client.send(res)
        except Exception:
            try:
                client.close()
            except Exception:
                discard
            return

#Start up the RPC's server socket.
proc listen*(
    rpc: RPC,
    config: Config
) {.forceCheck: [], async.} =
    #Create the server socket.
    try:
        rpc.server = newAsyncSocket()
    except FinalAttributeError as e:
        doAssert(false, "Server is already listening: " & e.msg)
    except ValueError as e:
        doAssert(false, "Failed to create the RPC's server socket due to a ValueError: " & e.msg)
    except IOSelectorsException as e:
        doAssert(false, "Failed to create the RPC's server socket due to an IOSelectorsException: " & e.msg)
    except Exception as e:
        doAssert(false, "Failed to create the RPC's server socket due to an Exception: " & e.msg)

    try:
        rpc.server.setSockOpt(OptReuseAddr, true)
        rpc.server.bindAddr(Port(config.rpcPort))
    except OSError as e:
        doAssert(false, "Failed to set the RPC's server socket options and bind it due to an OSError: " & e.msg)
    except ValueError as e:
        doAssert(false, "Failed to bind the RPC's server socket due to a ValueError: " & e.msg)

    #Start listening.
    try:
        rpc.server.listen()
    except OSError as e:
        doAssert(false, "Failed to start listening on the RPC's server socket due to an OSError: " & e.msg)
    except Exception as e:
        doAssert(false, "Failed to start listening on the RPC's server socket due to an Exception: " & e.msg)

    #Add a repeating timer to remove dead RPC clients.
    try:
        addTimer(
            60000,
            false,
            proc (
                fd: AsyncFD
            ): bool {.forceCheck: [].} =
                var i: int = 0
                while i < rpc.clients.len:
                    if rpc.clients[i].isClosed():
                        rpc.clients.delete(i)
                        continue
                    inc(i)
        )
    except OSError as e:
        doAssert(false, "Couldn't set a timer due to an OSError: " & e.msg)
    except Exception as e:
        doAssert(false, "Couldn't set a timer due to an Exception: " & e.msg)

    #Accept new connections infinitely.
    while not rpc.server.isClosed():
        #Add the Client to the seq.
        #Receive the new client.
        var connection: AsyncSocket
        try:
            connection = await rpc.server.accept()
        except Exception:
            #This could happen by a crtical error, a closed server socket, or a bad client. We don't have enough info.
            #In the first case, we should crash. In the second, break. #In the third, continue.
            #If the socket is closed, continuuing will break. Therefore, a continue covers two/three cases and tries to keep going.
            continue

        #Add the new client to the list.
        rpc.clients.add(connection)

        try:
            asyncCheck rpc.handle(connection)
        except Exception as e:
            doAssert(false, "Handle threw an Exception despite not naturally throwing anything: " & e.msg)
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

    #Close each client.
    while rpc.clients.len != 0:
        try:
            rpc.clients[0].close()
        except Exception:
            discard
        rpc.clients.delete(0)
