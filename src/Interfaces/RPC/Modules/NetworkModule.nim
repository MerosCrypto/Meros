#Errors lib.
import ../../../lib/Errors

#GlobalFunctionBox object.
import ../../../objects/GlobalFunctionBoxObj

#RPC object.
import ../objects/RPCObj

#Async standard lib.
import asyncdispatch

#Async networking standard lib.
import asyncnet

#Default network port.
const DEFAULT_PORT {.intdefine.}: int = 5132

#Create the Network module.
proc module*(
    functions: GlobalFunctionBox
): RPCFunctions {.forceCheck: [].} =
    try:
        newRPCFunctions:
            #Connect to a new node.
            "connect" = proc (
                res: JSONNode,
                params: JSONNode
            ): Future[void] {.forceCheck: [
                ParamError,
                JSONRPCError
            ], async.} =
                #Verify the parameters length.
                if (params.len != 1) and (params.len != 2):
                    raise newException(ParamError, "")

                #Verify the paramters types.
                if params[0].kind != JString:
                    raise newException(ParamError, "")

                #Supply the optional port argument if needed.
                if params.len == 1:
                    params.add(% DEFAULT_PORT)
                if params[1].kind != JInt:
                    raise newException(ParamError, "")

                try:
                    await functions.network.connect(params[0].getStr(), params[1].getInt())
                except ClientError:
                    raise newJSONRPCError(-6, "Couldn't connect")
                except Exception as e:
                    doAssert(false, "MainNetwork's connect threw an Exception despite not naturally throwing anything: " & e.msg)

            #Get the peers we're connected to.
            "getPeers" = proc (
                res: JSONNode,
                params: JSONNode
            ): Future[void] {.forceCheck: [], async.} =
                res["result"] = % []

                for client in functions.network.getPeers():
                    try:
                        res["result"].add(%* {
                            "ip": client.socket.getPeerAddr()[0],
                            "server": client.server
                        })
                    except KeyError as e:
                        doAssert(false, "Couldn't set the result: " & e.msg)
                    except OSError as e:
                        doAssert(false, "Couldn't get the peer address from a connected socket: " & e.msg)

                    if client.server:
                        try:
                            res["result"]["port"] = % client.port
                        except KeyError as e:
                            doAssert(false, "Couldn't add the port the result: " & e.msg)
    except Exception as e:
        doAssert(false, "Couldn't create the Network Module: " & e.msg)
