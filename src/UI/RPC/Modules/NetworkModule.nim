#Errors lib.
import ../../../lib/Errors

#RPC object.
import ../objects/RPCObj

#EventEmitter lib.
import ec_events

#Async standard lib.
import asyncdispatch

#String utils standard lib.
import strutils

#JSON standard lib.
import json

#Default network port.
const DEFAULT_PORT {.intdefine.}: int = 5132

#Connect to a new node.
proc connect*(
    rpc: RPC,
    ip: string,
    port: int
): Future[JSONNode] {.async.} =
    try:
        #Connect to a new node.
        if not await rpc.events.get(
            proc (ip: string, port: int): Future[bool],
            "network.connect"
        )(ip, port):
            result = %* {
                "error": "Couldn't connect to the IP/Port."
            }
    except:
        raise newException(EventError, "Couldn't get and call network.connect.")

#Handler.
proc networkModule*(
    rpc: RPC,
    json: JSONNode,
    reply: proc (json: JSONNode)
) {.async.} =
    #Declare a var for the response.
    var res: JSONNode

    #Put this in a try/catch in case the method fails.
    try:
        #Switch based off the method.
        case json["method"].getStr():
            of "connect":
                res = await rpc.connect(
                    json["args"][0].getStr(),
                    if json["args"].len == 2: json["args"][1].getInt() else: DEFAULT_PORT
                )

            else:
                res = %* {
                    "error": "Invalid method."
                }
    except:
        #If there was an issue, make the response the error message.
        res = %* {
            "error": getCurrentExceptionMsg()
        }

    reply(res)
