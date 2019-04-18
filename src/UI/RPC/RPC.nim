#Errors lib.
import ../../lib/Errors

#Config object.
import ../../objects/ConfigObj

#RPC object.
import objects/RPCObj
export RPCObj

#RPC modules.
import Modules/SystemModule
import Modules/PersonalModule
import Modules/VerificationsModule
import Modules/MeritModule
import Modules/LatticeModule
import Modules/NetworkModule

#Async standard lib.
import asyncdispatch

#Networking standard lib.
import asyncnet

#Selectors standard lib, imported for an Error type asyncnet can raise but doesn't export.
import selectors

#JSON standard lib.
import json

#Sequtils standared lib.
import sequtils

#Constructor.
proc newRPC*(
    functions: GlobalFunctionBox,
    toRPC: ptr Channel[JSONNode],
    toGUI: ptr Channel[JSONNode]
): RPC {.forceCheck: [].} =
    newRPCObj(
        functions,
        toRPC,
        toGUI
    )

#Handle a message.
proc handle(
    rpc: RPC,
    msg: JSONNode,
    reply: proc (
        json: JSONNode
    ) {.raises: [].}
) {.forceCheck: [], async.} =
    #Switch based off the moduke.
    var moduleStr: string
    try:
        moduleStr = msg["module"].getStr()
    except KeyError:
        reply(%* {
            "error": "No module specified."
        })
        return

    try:
        case moduleStr:
            of "system":
                await rpc.system(msg, reply)
            of "personal":
                await rpc.personal(msg, reply)
            of "verifications":
                await rpc.verifications(msg, reply)
            of "merit":
                await rpc.merit(msg, reply)
            of "lattice":
                await rpc.lattice(msg, reply)
            of "network":
                await rpc.network(msg, reply)
            else:
                reply(
                    %* {
                        "error": "Unrecognized module."
                    }
                )
    except Exception as e:
        doAssert(false, "An RPC module/reply threw an Exception despite not naturally throwing anything: " & e.msg)

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

        #Handle the data.
        try:
            asyncCheck rpc.handle(
                data.msg,
                proc (
                    json: JSONNode
                ) {.forceCheck: [].} =
                    try:
                        rpc.toGUI[].send(json)
                    except DeadThreadError as e:
                        doAssert(false, "Couldn't send data to the GUI due to a DeadThreadError: " & e.msg)
                    except Exception as e:
                        doAssert(false, "Couldn't send data to the GUI due to an Exception: " & e.msg)
            )
        except Exception as e:
            doAssert(false, "rpc.handle threw an Exception despite not naturally throwing anything: " & e.msg)

#Handle a Socket Client.
proc handle*(
    rpc: RPC,
    client: RPCSocketClient
) {.forceCheck: [], async.} =
    #Handle the client.
    while not client.socket.isClosed():
        #Read in a line.
        var data: string
        try:
            data = await client.socket.recvLine()
        except Exception:
            discard
        #If the line length is 0, the client is invalid. Stop handling it.
        if data.len == 0:
            try:
                client.socket.close()
            except Exception:
                discard
            for i in 0 ..< rpc.clients.len:
                if rpc.clients[i].id == client.id:
                    rpc.clients.delete(i)
            break

        #Parse the JSON.
        var json: JSONNode
        try:
            json = parseJSON(data)
        except Exception:
            try:
                asyncCheck client.socket.send(
                    $(%* {
                        "error": "Invalid RPC payload."
                    }) & "\r\n"
                )
            except Exception:
                try:
                    client.socket.close()
                except Exception:
                    discard
                for i in 0 ..< rpc.clients.len:
                    if rpc.clients[i].id == client.id:
                        rpc.clients.delete(i)
                break
            continue

        #Handle the data.
        try:
            asyncCheck rpc.handle(
                json,
                proc (
                    resArg: JSONNode
                ) {.forceCheck: [].} =
                    #Declare a var to send back.
                    var res: string
                    try:
                        #If resArg is nil...
                        if resArg.isNil:
                            #Set a default response of success.
                            res = $(%* {
                                "success": true
                            })
                        #Else, use the resArg.
                        else:
                            res = $resArg
                    except KeyError as e:
                        doAssert(false, "Couldn't serialize a JSON response: " & e.msg)

                    #Send it.
                    try:
                        asyncCheck client.socket.send(res & "\r\n")
                    except Exception as e:
                        echo "Couldn't send `" & res & "` to a RPC client: " & e.msg
                        try:
                            client.socket.close()
                        except Exception:
                            discard
                        for i in 0 ..< rpc.clients.len:
                            if rpc.clients[i].id == client.id:
                                rpc.clients.delete(i)
            )
        except Exception as e:
            doAssert(false, "Handle(JSONNode) threw an Exception despite not naturally throwing anything: " & e.msg)


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

#Shutdown.
proc shutdown*(
    rpc: RPC
) {.forceCheck: [].} =
    #Set listening to false.
    rpc.listening = false

    #Close the server socket.
    try:
        rpc.server.close()
    except Exception:
        discard
    #Close each client.
    for client in rpc.clients:
        try:
            client.socket.close()
        except Exception:
            discard
