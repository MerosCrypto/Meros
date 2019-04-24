#Errors lib.
import ../../../lib/Errors

#RPC object.
import ../objects/RPCObj

#Async standard lib.
import asyncdispatch

#JSON standard lib.
import json

#Default network port.
const DEFAULT_PORT {.intdefine.}: int = 5132

#Connect to a new node.
proc connect*(
    rpc: RPC,
    ip: string,
    port: int
) {.forceCheck: [], async.} =
    try:
        await rpc.functions.network.connect(ip, port)
    except Exception as e:
        doAssert(false, "MainNetwork's connect threw an Exception despite not naturally throwing anything: " & e.msg)

#Handler.
proc network*(
    rpc: RPC,
    json: JSONNode,
    reply: proc (json: JSONNode)
) {.forceCheck: [], async.} =
    #Declare a var for the response.
    var res: JSONNode

    #Switch based off the method.
    var methodStr: string
    try:
        methodStr = json["method"].getStr()
    except KeyError:
        reply(%* {
            "error": "No method specified."
        })
        return

    try:
        case methodStr:
            of "connect":
                try:
                    await rpc.connect(
                        json["args"][0].getStr(),
                        if json["args"].len == 2: json["args"][1].getInt() else: DEFAULT_PORT
                    )
                except Exception as e:
                    doAssert(false, "NetworkModule's connect threw an Exception despite not naturally throwing anything: " & e.msg)


            else:
                res = %* {
                    "error": "Invalid method."
                }
    except KeyError:
        res = %* {
            "error": "Missing `args`."
        }

    reply(res)
