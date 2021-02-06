import json

import chronos

import ../../../lib/Errors

import ../../../objects/GlobalFunctionBoxObj

import ../objects/RPCObj

proc module*(
  functions: GlobalFunctionBox
): RPCHandle {.forceCheck: [].} =
  try:
    result = newRPCHandle:
      proc quit(
        req: JSONRPCRequest,
        reply: RPCReplyFunction
      ) {.requireAuth, forceCheck: [], async.} =
        try:
          await reply(% {
            "jsonrpc": "2.0",
            "id": req["id"],
            "result": true
          })
        except Exception as e:
          panic("Couldn't call reply about how we're quitting due to an Exception despite reply not naturally throwing anything: " & e.msg)

        functions.system.quit()

  except Exception as e:
    panic("Couldn't create the System Module: " & e.msg)
