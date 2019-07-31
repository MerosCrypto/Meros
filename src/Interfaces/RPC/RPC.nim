#Errors lib.
import ../../lib/Errors

#Config object.
import ../../objects/ConfigObj

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
    res: var JSONNode,
    code: int,
    msg: string,
    data: JSONNode = nil
) {.forceCheck: [].} =
    res["error"] = %* {
        "code": code,
        "message": msg
    }
    if not data.isNil:
        res["error"]["data"] = data

#Create a new error response.
proc error(
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
    res: var JSONNode,
    reply: proc (
        res: JSONNode
    ) {.raises: [].}
) {.forceCheck: [], async.} =
    #Verify the version.
    if (not req.hasKey("jsonrpc")) or (req["jsonrpc"].getStr() != "2.0"):
        error(res, -32600, "Invalid Request")
        return

    #Verify the method exists.
    if (not req.hasKey("method")) or (req["method"].kind != JString):
        error(res, -32600, "Invalid Request")
        return

    #Add params if it was omitted.
    if (not req.hasKey("params")):
        req["params"] = % []

    #Make sure the param were an array.
    if req["params"].kind != JArray:
        error(res, -32600, "Invalid Request")
        return

    try:
        #OVerride for system_quit.
        if req["method"].getStr() == "system_quit":
            res["result"] = true
            reply(res)
            await rpc.quit()

        #Make sure the method exists.
        if not rpc.hasKey(req["method"].getStr()):
            error(res, -32601, "Method not found")
            return

        #Call the method.
        await rpc.functions[req["method"].getStr()](res, req["params"])
    #If there was an invalid parameter, create the proper error response.
    except ParamError:
        res = error(req["id"], -32602, "Invalid params")
        return

    #If a parameter had an invalid value, create the proper response.
    except JSONRPCError as e:
        res = error(req["id"], e.code, e.msg, e.data)
        return

    #If we doAssert(false), make sure it bubbles up.
    except AssertionError as e:
        doAssert(false, "RPC caused a doAssert(false): " & e.msg)

    #Else, respond that we had an internal error.
    #Generally, we would doAssert(false) here, yet the amount of custom data that can be entered makes that a worrysome prospect.
    except Exception:
        res = error(req["id"], -32603, "Internal error")
        return

#Handle a request and return the result.
proc handle*(
    rpc: RPC,
    req: JSONNode,
    reply: proc (
        res: JSONNode
    ) {.raises: [].}
): JSONNode {.forceCheck: [].} =
    #If this is a singular request...
    if req.kind == JObject:
        #Add an ID if it was omitted.
        if not req.hasKey("id"):
            req["id"] = % nil

        #Create the response.
        result = %* {
            "jsonrpc": "2.0",
            "id": req["id"]
        }

        #Handle it.
        handle(rpc, req, result, reply)

    #If this was a batch request...
    elif req.kind == JArray:
        #Prepare the result.
        var results: JSONNode = newJArray()

        #Iterate over each request.
        for reqElem in req:
            #Add an ID if it was omitted.
            if not reqElem.hasKey("id"):
                reqElem["id"] = % nil

            #Prepare this specific result.
            result = %* {
                "jsonrpc": "2.0",
                "id": reqElem["id"]
            }

            #Check the request's type.
            if reqElem.kind != JObject:
                results.add(error(-32600, "Invalid Request"))
                continue

            #Handle it.
            handle(
                rpc,
                reqElem,
                result,
                proc (
                    res: JSONNode
                ) {.forceCheck: [].} =
                    results.add(res)
                    reply(results)
            )

            #If there was a result, add it.
            if not result.isNil:
                results.add(result)

        #Set result to results.
        result = results

    else:
        error(result, -32600, "Invalid Request")
        return

#Handle a string and return a string.
proc handle*(
    rpc: RPC,
    reqStr: string
    reply: proc (
        res: string
    ) {.raises: [].}
): string =
    var
        req: JSONNode
        res: JSONNode

    #Parse the request.
    try:
        req = parseJSON(reqStr)
    except JSONParsingError:
        return $error(newJNull(), -32700, "Parse error")

    #Handle it.
    res = rpc.handle(
        req,
        proc (
            res: JSONNode
        ) {.forceCheck: [].} =
            reply($res)
    )

    #Return the string.
    if res.isNil:
        result = ""
    else:
        result = $res

#Start up the RPC's connection to the GUI.
proc start*(
    rpc: RPC
) {.forceCheck: [], async.} =
    while rpc.listening:
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
        var res: JSONNode = rpc.handle(
            req,
            proc (
                replyArg: JSONNode
            ) {.forceCheck: [].} =
                rpc.toGUI[].send(replyArg)
        )
        rpc.toGUI[].send(res)

discard """
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

    #Accept new connections infinitely.
    var id: int = 0
    while (rpc.listening) and (not rpc.server.isClosed()):
        #Add the Client to the seq.
        #Receive the new client.
        var client: AsyncSocket
        try:
            client = await rpc.server.accept()
        except Exception:
            #This could happen by a crtical error, a closed server socket, or a bad client. We don't have enough info.
            #In the first case, we should crash. In the second, break. #In the third, continue.
            #If the socket is closed, continuuing will break. Therefore, a continue covers two/three cases and tries to keep going.
            continue

        rpc.clients.add(
            newRPCSocketClient(
                id,
                client
            )
        )
        #Handle it.
        try:
            asyncCheck rpc.handle(rpc.clients[^1])
        except Exception as e:
            doAssert(false, "Handle(RPCSocketClient) threw an Exception despite not naturally throwing anything: " & e.msg)
        #Increment the ID counter.
        inc(id)
"""

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
            rpc.clients[0].socket.close()
        except Exception:
            discard
        rpc.clients.delete(0)
