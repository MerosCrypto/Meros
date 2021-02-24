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
  404: "Not Found",
  405: "Method Not Allowed",
  406: "Not Acceptable",
  411: "Length Required",
  412: "Precondition Failed",
  413: "Payload Too Large",
  417: "Expectation Failed",
  505: "HTTP Version Not Supported"
}.toTable()

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

  for header in socket.headers.keys():
    try:
      res &= header & ": " & socket.headers[header] & "\r\n"
    except KeyError as e:
      panic("Couldn't get a header despite confirming its existence: " & e.msg)
  res &= "\r\n" & body

  try:
    await socket.send(res)
    #Supposed to close after this response.
    if not (socket.headers.hasKey("Connection") and (socket.headers["Connection"] == "keep-alive")):
      socket.close()
  except KeyError as e:
    panic("Couldn't get the Connection header despite confirming its existence: " & e.msg)
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
  if code == 405:
    socket.headers["Allow"] = "HEAD, GET, POST"

  try:
    await socket.sendHTTP(code)
  except Exception as e:
    panic("sendHTTP threw an Exception despite not naturally throwing anything: " & e.msg)

proc writeHTTP*(
  socket: RPCSocket,
  json: string
) {.forceCheck: [], async.} =
  if not socket.headers.hasKey("Content-Type"):
    socket.headers["Content-Type"] = "application/json"
  socket.headers["Content-Length"] = $json.len
  socket.headers["Cache-Control"] = "no-store"
  try:
    await socket.sendHTTP(200, json)
  except Exception as e:
    panic("sendHTTP threw an Exception despite not naturally throwing anything: " & e.msg)

proc httpUnauthorized*(
  socket: RPCSocket
) {.forceCheck: [], async.} =
  try:
    await socket.httpStatus(401)
  except Exception as e:
    panic("sendHTTP threw an Exception despite not naturally throwing anything: " & e.msg)

#Reads a RPC call over HTTP and returns it.
#Non-RPC calls, such as HEAD/GET, are handled without returning.
proc readHTTP*(
  socket: RPCSocket
): Future[string] {.forceCheck: [], async.} =
  template HTTP_STATUS(
    code: int
  ) =
    try:
      await socket.httpStatus(code)
    except Exception as e:
      panic("Couldn't send a HTTP status despite httpStatus not naturally throwing anything: " & e.msg)

  while not socket.closed():
    block thisReq:
      #Needed to prevent an async lockup; I'm actually not sure where such lockup occurs.
      #-- Kayaba
      try:
        await sleepAsync(1)
      except Exception as e:
        panic("Couldn't sleep before receving the next HTTP request: " & e.msg)

      #Clear the socket's last headers.
      socket.headers = initTable[string, string]()

      #Read the start line.
      var line: string
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
      if startLine.len != 3:
        HTTP_STATUS(400)
        continue
      case startLine[0]:
        of "HEAD", "GET":
          HTTP_STATUS(404)
          continue
        of "POST":
          discard
        else:
          HTTP_STATUS(405)
          continue
      if startLine[2] != "HTTP/1.1":
        HTTP_STATUS(505)
        continue

      #First header/blank line for header section termination.
      try:
        line = await socket.readLine()
      except Exception as e:
        panic("Couldn't read a header despite readLine not naturally throwing anything: " & e.msg)
      if socket.closed:
        return
      var
        parts: seq[string]
        #expectContinue: bool = false
        contentLength: int = -1
      while line != "":
        parts = line.split(" ")
        #[
        #Process this header.
        if line == "Expect: 100-continue":
          expectContinue = true
          line = await socket.readLine()
          break thisReq
        ]#

        case parts[0]:
          #[
          #Used to figure out the best content type to use.
          #Errors if none are, for some reason.
          of "Accept:":
            var toUse: string = supported(JSON_MIME_TYPES, line):
            if toUse == "":
              await socket.httpStatus(406)
              break thisReq

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
          of "Accept-Charset:":
            if not supported(CHARSETS, line):
              await socket.httpStatus(406)
              break thisReq
          ]#

          #This should also never come in a meaningful way, yet it can be easily checked without a comprehensive list.
          of "Accept-Encoding:":
            #If compression is required, error.
            if line.contains("*;q=0") or line.contains("identity;q=0"):
              await socket.httpStatus(406)
              break thisReq

          of "Expect:":
            await socket.httpStatus(417)
            break thisReq
          ]#

          of "Content-Length:":
            #Max of 9999 bytes, which would only come close during batch requests.
            if parts[1].len > 4:
              HTTP_STATUS(413)
              break thisReq
            try:
              contentLength = int(parseUInt(parts[1]))
            except ValueError:
              HTTP_STATUS(400)
              break thisReq

        #[
          of "Connection:":
            socket.headers["Connection"] = part[1]

        #If there's any conditional statement, assume it's invalid.
        if parts[0].contains("If-"):
          await socket.httpStatus(412)
          continue
        ]#

        #Grab the next header.
        try:
          line = await socket.readLine()
        except Exception as e:
          panic("Couldn't read a header despite readLine not naturally throwing anything: " & e.msg)
        if socket.closed:
          return

      #Make sure the content length was provided.
      if contentLength == -1:
        HTTP_STATUS(411)
        continue

      #If the client was solely validating their headers, move on to the next message.
      #[
      if expectContinue:
        await socket.httpStatus(100)
        continue
      ]#

      #Read the body.
      try:
        return await socket.recv(contentLength)
      except Exception as e:
        panic("Couldn't read the body despite recv not naturally throwing anything: " & e.msg)
