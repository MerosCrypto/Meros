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
    newRPCFunctions:
        #Connect to a new node.
        "connect" = proc (
            res: var JSONNode,
            params: JSONNode
        ): Future[void] {.forceCheck: [], async.} =
            #Verify the parameters length.
            if (params.len != 1) and (params.len != 2):
                raise newException(ParamError)

            #Verify the paramters types.
            if params[0].kind != JString:
                raise newException(ParamError)

            #Supply the optional port argument if needed.
            if params.len == 1:
                params.add(% DEFAULT_PORT)
            if params[1].kind != JInt:
                raise newException(ParamError)

            try:
                await rpc.functions.network.connect(params[0].getString(), params[1].getInt())
            except ClientError as e:
                raise newJSONRPCError(-6, e.msg)
            except Exception as e:
                doAssert(false, "MainNetwork's connect threw an Exception despite not naturally throwing anything: " & e.msg)

            res["result"] = % true
