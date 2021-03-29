import strutils
import tables

import chronos

import ../../lib/Errors

import objects/RPCObj

#text/plain is a legacy format, yet it's also used when context is unavailable, which this caters to.
const JSON_MIME_TYPES: seq[string] = @["application/json", "application/*", "text/plain", "text/*", "*/*"]

const STATUSES: Table[int, string] = {
  100: "Continue",
  200: "OK",
  400: "Bad Request",
  401: "Unauthorized",
  405: "Method Not Allowed",
  #406: "Not Acceptable",
  411: "Length Required",
  #412: "Precondition Failed",
  413: "Payload Too Large",
  415: "Unsupported Media Type",
  #416: "Range Not Satisfiable"
  417: "Expectation Failed",
  431: "Request Header Fields Too Large",
  505: "HTTP Version Not Supported"
}.toTable()

proc supported(
  supportedTypes: seq[string],
  parts: seq[string]
): string {.forceCheck: [].} =
  for i in 1 ..< parts.len:
    if supportedTypes.contains(parts[i].split(";")[0].toLowerAscii()):
      return parts[i]

proc sendHTTP(
  socket: RPCSocket,
  code: int,
  body: string = ""
) {.forceCheck: [], async.} =
  var res: string = "HTTP/1.1 " & $code & " "
  try:
    res &= STATUSES[code] & "\r\n"
  except KeyError as e:
    panic("Couldn't get a status's message despite having a constant table and only using a select few: " & e.msg)

  socket.headers["Content-Length"] = $body.len
  #Only send these headers when there's a body to refer to.
  #Especially important for Content-Type as that can be disagreeable.
  if code == 200:
    if not socket.headers.hasKey("Content-Type"):
      socket.headers["Content-Type"] = "application/json"
    socket.headers["Transfer-Encoding"] = "identity"
    socket.headers["Cache-Control"] = "no-store"
  #Set a connection type of close. Avoids extensive socket tracking and a few headers.
  if code != 100:
    socket.headers["Connection"] = "close"
  for header in socket.headers.keys():
    try:
      #Don't send the Connection header for the default policy.
      if (header == "Connection") and (socket.headers[header] == "keep-alive"):
        continue
      res &= header & ": " & socket.headers[header] & "\r\n"
    except KeyError as e:
      panic("Couldn't get a header despite confirming its existence: " & e.msg)
  res &= "\r\n" & body

  try:
    await socket.send(res)
    #Supposed to close after this response.
    if socket.headers.hasKey("Connection") and (socket.headers["Connection"] == "close"):
      socket.close()
  except KeyError as e:
    panic("Couldn't get the Connection header despite defining it if it didn't exist: " & e.msg)
  except Exception as e:
    logWarn "Couldn't send a response to a RPC client; this may supposed to be fatal", err = e.msg
    try:
      socket.close()
    #Move on.
    except Exception:
      discard

proc httpStatus(
  socket: RPCSocket,
  code: int
) {.forceCheck: [], async.} =
  if code == 401:
    socket.headers["WWW-Authenticate"] = "Bearer realm=\"\", charset=\"UTF-8\""
  elif code == 405:
    socket.headers["Allow"] = "HEAD, GET, POST"

  try:
    await socket.sendHTTP(code)
  except Exception as e:
    panic("sendHTTP threw an Exception despite not naturally throwing anything: " & e.msg)

template writeHTTP*(
  socket: RPCSocket,
  json: string
): Future[void] =
  mixin sendHTTP
  socket.sendHTTP(200, json)

proc httpUnauthorized*(
  socket: RPCSocket
) {.forceCheck: [], async.} =
  try:
    await socket.httpStatus(401)
  except Exception as e:
    panic("httpStatus threw an Exception despite not naturally throwing anything: " & e.msg)

#Reads a RPC call over HTTP and returns it.
#Non-RPC calls, such as HEAD/GET, are handled without returning.
proc readHTTP*(
  socket: RPCSocket
): Future[tuple[body: string, token: string]] {.forceCheck: [], async.} =
  template HTTP_STATUS(
    code: int
  ) =
    try:
      await socket.httpStatus(code)
    except Exception as e:
      panic("Couldn't send a HTTP status despite httpStatus not naturally throwing anything: " & e.msg)

  while not socket.closed():
    block thisReq:
      #Clear the result.
      result = (body: "", token: "")

      #Needed to prevent an async lockup; I'm actually not sure where such lockup occurs.
      #-- Kayaba
      try:
        await sleepAsync(1.milliseconds)
      except Exception as e:
        panic("Couldn't sleep before receving the next HTTP request: " & e.msg)

      #Clear the socket's last headers.
      socket.headers = initTable[string, string]()

      var
        chunked: bool = false
        line: string
      #Read the start line.
      try:
        line = await socket.readLine()
      except Exception as e:
        panic("Couldn't read the start line despite readLine not naturally throwing anything: " & e.msg)
      if socket.closed:
        return
      #Verify this is a start line. If it's not, move on.
      #Rather naive check, yet should work well enough.
      #Generally used since we process headers as they come in, instead of reading the entire message first.
      #Also handles misc newlines.
      let startLine: seq[string] = line.split(" ")
      if (
        (startLine.len != 3) or
        (startLine[0] != startLine[0].toUpperAscii()) or
        (not startLine[1].contains("/")) or
        (startLine[2][0 ..< 7] != "HTTP/1.")
      ):
        continue

      #Now that we've confirmed it's the start line, handle it.
      #This following check is pointless due to the above.
      if startLine.len != 3:
        HTTP_STATUS(400)
        continue
      #Ensure this is a POST. The HTTP spec technically requires GET/HEAD to never return 405.
      #That said, we don't use them at all, so we just move on with the simpler solution.
      if startLine[0] != "POST":
        HTTP_STATUS(405)
        continue
      if startLine[2] != "HTTP/1.1":
        HTTP_STATUS(505)
        continue

      var
        headerCount: int = 0
        expectContinue: bool = false
        contentLength: int = -1
      while true:
        #Read the header.
        try:
          line = await socket.readLine()
        except Exception as e:
          panic("Couldn't read a header despite readLine not naturally throwing anything: " & e.msg)
        if socket.closed:
          return

        if line == "":
          break

        if line.len > 100:
          HTTP_STATUS(431)
          break thisReq
        inc(headerCount)
        if headerCount > 20:
          HTTP_STATUS(431)
          break thisReq

        var parts: seq[string] = line.split(" ").join("").split(":")
        if parts.len < 2:
          HTTP_STATUS(400)
          break thisReq

        #Process this header.
        if (parts[0] == "Expect") and (parts[1].toLowerAscii() == "100-continue"):
          expectContinue = true
          continue

        #[
        if parts[0].contains("Range"):
          HTTP_STATUS(416)
          continue
        ]#

        case parts[0]:
          #Used to figure out the best content type to use.
          #If no content types work, the traditional solution is to move on anyways (despite not following the spec).
          #Question is do generic, and specific, HTTP libs prefer text/plain or application/json...
          of "Accept":
            var toUse: string = supported(JSON_MIME_TYPES, parts)
            if toUse == "":
              #HTTP_STATUS(406)
              #break thisReq
              toUse = "application/json"

            #Handle wildcard values.
            if toUse == "text/*":
              toUse = "text/plain"
            #application/* and */*
            if toUse.contains("*"):
              toUse = "application/json"

            socket.headers["Content-Type"] = toUse

          #Commented as any ASCII compatible charset will work.
          #This means numerous charsets will incorrectly decode, yet them being chosen is such an edge case...
          #Easier to have wide support, yet this comment block serves as an ack to their existence.
          #[
          of "Accept-Charset":
            var toUse: string = supported(CHARSETS, parts):
            if toUse == "":
              HTTP_STATUS(406)
              break thisReq
            socket.headers["Charset"] = toUse
          ]#

          #[
          #Even though a list of accepted encodings are defined, we ultimately decide which to use, which can be any.
          #The identity should be universally accepted, especially given context of what this is.
          #Hence why we don't needlessly error (or bother with this).
          of "Accept-Encoding":
            #If compression is required, error.
            if (
              #Identity was disabled.
              line.contains("identity;q=0,") or line.contains("identity;q=0 ") or
              #All that weren't explicitly mentioned were disabled, and identity wasn't explicitly mentioned.
              #Identity being explicitly mentioned yet also set to 0 is handled in the above check.
              (line.contains("*;q=0") and (not line.contains("identity")))
            ):
              HTTP_STATUS(406)
              break thisReq
          ]#

          #Don't accept compressed requests.
          of "Content-Encoding":
            HTTP_STATUS(415)
            break thisReq

          #We only handle 100-continue, as defined above.
          of "Expect":
            HTTP_STATUS(417)
            break thisReq

          #curl defaults to x-www-form-urlencoded.
          #We should really just try to handle the body no matter what.
          #[
          of "Content-Type":
            if not ["application/json", "text/plain"].contains(parts[1]):
              HTTP_STATUS(415)
              break thisReq
          ]#

          of "Content-Length":
            #Max of 9999 bytes, which would only come close during batch requests.
            if parts[1].len > 4:
              HTTP_STATUS(413)
              break thisReq
            try:
              contentLength = int(parseUInt(parts[1]))
            except ValueError:
              HTTP_STATUS(400)
              break thisReq

          of "Authorization":
            var authParts: seq[string] = line.split(" ")
            if authParts.len < 2:
              HTTP_STATUS(400)
              break thisReq
            elif (authParts[^2] != "Bearer"):
              HTTP_STATUS(401)
              break thisReq
            result.token = authParts[^1]

          of "Connection":
            if parts[1].split(",").contains("keep-alive"):
              socket.headers["Connection"] = "keep-alive"

          of "Transfer-Encoding":
            if parts[1] == "identity":
              discard
            elif parts[1] == "chunked":
              chunked = true
            else:
              HTTP_STATUS(415)

        #[
        #If there's any conditional statement, we can assume it's invalid or ignore it.
        #This comment block shows we're ignoring it.
        if parts[0].contains("If-"):
          HTTP_STATUS(412)
          continue
        ]#

      #Make sure the content length was provided.
      if (not chunked) and (contentLength == -1):
        HTTP_STATUS(411)
        break thisReq

      #If the client was solely validating their headers, move on to the next message.
      if expectContinue:
        HTTP_STATUS(100)

      #Read the body.
      if chunked:
        while true:
          var length: string
          try:
            length = await socket.readLine()
          except Exception as e:
            panic("Couldn't read the chunk length despite readLine not naturally throwing anything: " & e.msg)
          if socket.closed:
            return

          if length.len > 4:
            HTTP_STATUS(413)
            break thisReq
          var parsedLen: int
          try:
            parsedLen = parseHexInt(length)
            if parsedLen < 0:
              #https://github.com/nim-lang/Nim/issues/17208
              HTTP_STATUS(413)
              break thisReq
            elif parsedLen == 0:
              return
          except ValueError:
            HTTP_STATUS(400)
            break thisReq

          if (result.body.len + parsedLen) > 9999:
            HTTP_STATUS(413)
            break thisReq

          try:
            result.body &= await socket.recv(parsedLen)
          except Exception as e:
            panic("Couldn't read the chunk despite recv not naturally throwing anything: " & e.msg)
          if socket.closed:
            return

          try:
            discard await socket.readLine()
          except Exception as e:
            panic("Couldn't read the new line characters despite readLine not naturally throwing anything: " & e.msg)
          if socket.closed:
            return

      else:
        try:
          #Doesn't check socket.closed as the calling function does.
          result.body = await socket.recv(contentLength)
          return
        except Exception as e:
          panic("Couldn't read the body despite recv not naturally throwing anything: " & e.msg)
