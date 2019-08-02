#Errors lib.
import ../../../lib/Errors

#GlobalFunctionBox object.
import ../../../objects/GlobalFunctionBoxObj

#RPC object.
import ../objects/RPCObj

#Async standard lib.
import asyncdispatch

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
    except Exception as e:
        doAssert(false, "Couldn't create the Network Module: " & e.msg)
