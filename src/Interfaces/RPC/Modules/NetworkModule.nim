#Errors lib.
import ../../../lib/Errors

#GlobalFunctionBox object.
import ../../../objects/GlobalFunctionBoxObj

#RPC object.
import ../objects/RPCObj

#Chronos external lib.
import chronos

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
        ParamError
      ], async.} =
        #Verify the parameters length.
        if (params.len != 1) and (params.len != 2):
          raise newLoggedException(ParamError, "")

        #Verify the paramters types.
        if params[0].kind != JString:
          raise newLoggedException(ParamError, "")

        #Supply the optional port argument if needed.
        if params.len == 1:
          params.add(% DEFAULT_PORT)
        if params[1].kind != JInt:
          raise newLoggedException(ParamError, "")

        try:
          await functions.network.connect(params[0].getStr(), params[1].getInt())
        except Exception as e:
          panic("MainNetwork's connect threw an Exception despite not naturally throwing anything: " & e.msg)

      #Get the peers we're connected to.
      "getPeers" = proc (
        res: JSONNode,
        params: JSONNode
      ): Future[void] {.forceCheck: [], async.} =
        res["result"] = % []

        for client in functions.network.getPeers():
          try:
            res["result"].add(%* {
              "ip": (
                $int(client.ip[0]) & "." &
                $int(client.ip[1]) & "." &
                $int(client.ip[2]) & "." &
                $int(client.ip[3])
              ),
              "server": client.server
            })
          except KeyError as e:
            panic("Couldn't set the result: " & e.msg)

          if client.server:
            try:
              res["result"][res["result"].len - 1]["port"] = % client.port
            except KeyError as e:
              panic("Couldn't add the port the result: " & e.msg)
  except Exception as e:
    panic("Couldn't create the Network Module: " & e.msg)
