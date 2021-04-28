import macros

import options
import sequtils
import strutils
import tables
import json

import chronos except Socket

import ../../../lib/Errors
import ../../../Network/objects/SocketObj
export recv

type
  RPCSocket* = ref object
    #Use the Networking socket which already has the proper helpies/safeties.
    socket: Socket
    #Headers to use in the response to the last request.
    headers*: Table[string, string]

  RPCReplyFunction* = proc (
    res: JSONNode
  ): Future[void] {.gcsafe.}

  RPCHandle* = proc (
    req: JSONNode,
    reply: RPCReplyFunction,
    authed: bool
  ): Future[void] {.gcsafe.}

  RPC* = ref object
    handle*: RPCHandle

    toRPC*: ptr Channel[JSONNode]
    toGUI*: ptr Channel[JSONNode]

    token*: string
    server*: StreamServer
    alive*: bool

  #Stub replaced with a string; used to signify to parse the string from hex.
  hex* = object

proc newRPCSocket*(
  socket: StreamTransport
): RPCSocket {.forceCheck: [], inline.} =
  RPCSocket(
    socket: newSocket(socket),
    headers: initTable[string, string]()
  )

proc closed*(
  socket: RPCSocket
): bool {.forceCheck: [], inline.} =
  socket.socket.closed

proc close*(
  socket: RPCSocket
) {.forceCheck: [], inline.} =
  socket.socket.safeClose("Told to close RPC socket")

proc send*(
  socket: RPCSocket,
  msg: string
) {.forceCheck: [], async.} =
  try:
    await socket.socket.send(msg)
  except SocketError:
    socket.close()
  except Exception as e:
    panic("Sending to an RPC socket raised an Exception despite catching all Exceptions: " & e.msg)

proc recv*(
  socket: RPCSocket,
  lenArg: int
): Future[string] {.forceCheck: [], async.} =
  var len: int = lenArg
  if socket.socket.readLineBuffer != char(0):
    result = $socket.socket.readLineBuffer
    socket.socket.readLineBuffer = char(0)
    len -= 1

  try:
    result &= await socket.socket.recv(len)
  except SocketError:
    socket.close()
  except Exception as e:
    panic("recv raised an Exception despite catching all Exceptions: " & e.msg)

proc readLine*(
  socket: RPCSocket
): Future[string] {.forceCheck: [], async.} =
  try:
    result = await socket.socket.readLine()
  except SocketError:
    socket.close()
  except Exception as e:
    panic("Reading a line from an RPC socket raised an Exception despite catching all Exceptions: " & e.msg)

template retrieveFromJSON*[T](
  value: JSONNode,
  expectedType: typedesc[seq[T]] or typedesc[T]
#Auto as hex != string (and so on).
): auto =
  when expectedType is Option:
    some(retrieveFromJSON(value, type(T().get())))
  elif expectedType is seq:
    if value.kind != JArray:
      #This function uses ParamError + message, an oddity, as ParamError has a hardcoded error message.
      #While that still applies to the actual RPC, this improves logging.
      raise newLoggedException(ParamError, "retrieveFromJSON wanted a seq and didn't get a JSON array.")

    mapIt(toSeq(value.items), retrieveFromJSON(it, type(T)))
  else:
    #NOP for raw JSONNode.
    when expectedType is JSONNode:
      value

    elif expectedType is bool:
      if value.kind != JBool:
        raise newLoggedException(ParamError, "retrieveFromJSON expected bool.")
      value.getBool()

    elif expectedType is SomeInteger:
      if value.kind != JInt:
        raise newLoggedException(ParamError, "retrieveFromJSON expected int.")
      let num: int = value.getInt()
      if num < int(low(T)):
        raise newLoggedException(ParamError, "retrieveFromJSON expected an int within a specific range.")

      #Differentiate if this is an int or uint. Needed as high(uint) won't fit into an int.
      when low(expectedType) != 0:
         if (num > int(high(T))):
           raise newLoggedException(ParamError, "retrieveFromJSON expected an int within a specific range.")
      else:
        if uint(num) > high(T):
          raise newLoggedException(ParamError, "retrieveFromJSON expected a uint within a specific range.")

      T(num)

    elif expectedType is string:
      if value.kind != JString:
        raise newLoggedException(ParamError, "retrieveFromJSON expected a string.")
      value.getStr()

    elif expectedType is hex:
      var res: string
      try:
        res = retrieveFromJSON(value, string)
        if res.substr(0, 1) == "0x":
          res = res.substr(2, res.len).parseHexStr()
        else:
          res = res.parseHexStr()
      except ValueError:
        raise newLoggedException(ParamError, "retrieveFromJSON expected a hex string.")
      res

    #Stops erroring when the Hash symbol isn't in scope.
    elif $(expectedType) == "Hash[256]":
      var res: string = retrieveFromJSON(value, hex)
      if res.len != 32:
        raise newLoggedException(ParamError, "retrieveFromJSON expected a 32-byte hex string (64 chars).")
      res.toHash[:256]()

    elif $(expectedType) == "EdPublicKey":
      var res: string = retrieveFromJSON(value, hex)
      if res.len != 32:
        raise newLoggedException(ParamError, "retrieveFromJSON expected a 32-byte hex string (64 chars).")
      newEdPublicKey(res)

    #BLS Public Key.
    elif $(expectedType) == "G2":
      var resStr: string = retrieveFromJSON(value, hex)
      if resStr.len != 96:
        raise newLoggedException(ParamError, "retrieveFromJSON expected a 96-byte hex string (192 chars).")

      var res: BLSPublicKey
      try:
        res = newBLSPublicKey(resStr)
      except BLSError as e:
        raise newJSONRPCError(ValueError, "Invalid BLS Public Key: " & e.msg)
      res

    elif $(expectedType) == "Address":
      var res: Address
      try:
        res = retrieveFromJSON(value, string).getEncodedData()
      except ValueError as e:
        raise newLoggedException(ParamError, "retrieveFromJSON expected a string that is a valid address: " & e.msg)
      res

    else:
      {.error: "Trying to get an unknown type from JSON: " & $expectedType.}

macro newRPCHandle*(
  routes: untyped
): untyped =
  #The generated function is a RPCHandle.
  #It needs to embody the functions passed in (routes), and also have a switch statement.
  #Said switch must format the parameters for the target function.
  #It finally needs to handle the reply logic.

  var
    body: NimNode = newStmtList(
      newEmptyNode(),
      #Default result of true.
      newVarStmt(ident("MACRO_res"), newCall(ident("%"), newLit(true)))
    )
    switch: NimNode = newNimNode(nnkCaseStmt).add(
      quote do:
        getStr(MACRO_rawReq["method"])
    )

  for route in routes:
    switch.add(newNimNode(nnkOfBranch))

    var
      argHandling: NimNode = newStmtList()
      routeCall: NimNode = newCall(route[0])
    for argument in route[3][1 ..< route[3].len]:
      var internalName: NimNode = ident("MACRO_ARGUMENT_" & argument[0].strVal)

      #If the argument isn't present, use the default value or fail.
      var defaultOrFail: NimNode
      if argument[2].kind != nnkEmpty:
        defaultOrFail = newAssignment(internalName, argument[2])
      else:
        defaultOrFail = quote do:
          raise newLoggedException(ParamError, "")

      let
        argumentName: string = argument[0].strVal.replace("_JSON")
        argumentType: NimNode = argument[1]

      #Enable direct access to request/reply; used by quit.
      if argumentType.kind == nnkIdent:
        if argumentType.strVal == "RPCRequest":
          routeCall.add(ident("MACRO_rawReq"))
          continue
        elif argumentType.strVal == "RPCReplyFunction":
          routeCall.add(ident("MACRO_reply"))
          continue

      var argumentActualType: NimNode = argumentType
      #Doesn't support Option[hex], something currently unused and unsupported elsewhere as well.
      if (argumentType.kind == nnkIdent) and (argumentType.strVal == "hex"):
        argumentActualType = ident("string")

      argHandling.add(
        quote do:
          var `internalName`: `argumentActualType`
          #Doesn't use a DotExpr for a more minimal AST.
          if hasKey(MACRO_rawReq["params"], `argumentName`):
            `internalName` = retrieveFromJSON(MACRO_rawReq["params"][`argumentName`], `argumentType`)
          else:
            `defaultOrFail`
      )

      #Make sure it's passed to the function.
      routeCall.add(internalName)

    var
      hasAsyncPragma: bool = false
      requiresAuth: bool = false
    for pragma in route[4]:
      if pragma.kind == nnkIdent:
        if pragma.strVal == "async":
          hasAsyncPragma = true
        elif pragma.strVal == "requireAuth":
          requiresAuth = true
          continue

    var returnType: NimNode = route[3][0]
    if hasAsyncPragma:
      if returnType.kind == nnkBracketExpr:
        returnType = returnType[0]
      #If this is async, add an await.
      routeCall = quote do:
        await `routeCall`

    #If it's not void, set MACRO_res.
    if (
      (returnType.kind != nnkEmpty) or
      (
        (returnType.kind == nnkIdent) and
        (returnType.strVal != "void")
      )
    ):
      routeCall = quote do:
        MACRO_res = %(`routeCall`)

    #Authorization check.
    if requiresAuth:
      argHandling = quote do:
        if not MACRO_authed:
          raise newLoggedException(RPCAuthorizationError, "401 Unauthorized")
        `argHandling`

    let caseBody: NimNode = argHandling
    caseBody.add(routeCall)
    switch[^1].add(newStrLitNode(route[0].strVal), caseBody)

  switch.add(newNimNode(nnkElse))
  switch[^1].add(
    quote do:
      raise newJSONRPCError(-32601, "Method not found")
  )

  body[0] = routes
  for r in 0 ..< body[0].len:
    #Replace instances of artificial types/remove default argument values.
    #Former are solely used as tags, latter is since they shouldn't be needed.
    for i in 1 ..< body[0][r][3].len:
      #Doesn't support Option[hex] which we don't use.
      if body[0][r][3][i][1].kind == nnkIdent:
        if body[0][r][3][i][1].strVal == "hex":
          body[0][r][3][i][1] = ident("string")
        elif body[0][r][3][i][1].strVal == "RPCRequest":
          body[0][r][3][i][1] = ident("JSONNode")
      body[0][r][3][i][2] = newNimNode(nnkEmpty)

    #Also remove requireAuth pragmas, since they're handled above and don't actually exist.
    for p in 0 ..< body[0][r][4].len:
      if (body[0][r][4][p].kind == nnkIdent) and (body[0][r][4][p].strVal == "requireAuth"):
        body[0][r][4].del(p)
        break

  body.add(switch)

  #Call reply.
  body.add(
    quote do:
      await MACRO_reply(%* {
        "jsonrpc": "2.0",
        "id": MACRO_rawReq["id"],
        "result": MACRO_res
      })
  )

  result = newProc(
    newEmptyNode(),
    @[
      newNimNode(nnkBracketExpr).add(
        ident("Future"),
        ident("void")
      ),
      newIdentDefs(ident("MACRO_rawReq"), ident("JSONNode")),
      newIdentDefs(ident("MACRO_reply"), ident("RPCReplyFunction")),
      newIdentDefs(ident("MACRO_authed"), ident("bool"))
    ],
    body,
    nnkLambda,
    quote do:
      {.closure, async, gcsafe.}
  )
