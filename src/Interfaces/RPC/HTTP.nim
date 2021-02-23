import tables

import chronos

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
  417: "Expectation Failed"
  505: "HTTP Version Not Supported"
}.toTable()

proc sendHTTP(
  socket: RPCSocket,
  req: HTTPRequest
  code: int,
  body: string = ""
) {.forceCheck: [], async.} =
  var res: string = "HTTP/1.1 " & $code & " "
  try:
    res &= STATUSES[code] & "\r\n"
  except KeyError as e:
    panic("Couldn't get a status's message despite having a constant table and only using a select few: " & e.msg)

  for header in req.headers.keys():
    try:
      res &= header & ": " & req.headers[header] & "\r\n"
    except KeyError as e:
      panic("Couldn't get a header despite confirming its existence: " & e.msg)
  res &= "\r\n"
  res &= json

  try:
    #Error when sending.
    if res.len != await socket.write(res):
      await socket.close()
    #Supposed to close after this response.
    if req.headers.hasKey("Connection") and (req.headers["Connection"] == "close"):
      socket.close()
  except KeyError as e:
    panic("Couldn't get the Connection header despite confirming its existence: " & e.msg)
  except Exception as e:
    logWarn "Couldn't send a response to a RPC client; this may supposed to be fatal", err = e.msg
    try:
      await socket.close()
    #Move on.
    except Exception:
      discard

proc httpStatus(
  socket: RPCSocket,
  req: HTTPRequest,
  code: int
) {.forceCheck: [], async.} =
  if code == 405:
    req.headers["Allow"] = "HEAD, GET, POST"

  try:
    socket.sendHTTP(req, code)
  except Exception as e:
    panic("sendHTTP threw an Exception despite not naturally throwing anything: " & e.msg)

proc writeHTTP*(
  socket: RPCSocket,
  req: HTTPRequest,
  json: string
) {.forceCheck: [], async.} =
  if not req.headers.hasKey("Content-Type"):
    req.headers["Content-Type"] = "application/json"
  req.headers["Content-Length"] = $json.len
  req.headers["Cache-Control"] = "no-store"
  try:
    socket.sendHTTP(req, 200, json)
  except Exception as e:
    panic("sendHTTP threw an Exception despite not naturally throwing anything: " & e.msg)

proc unauthorized*(
  socket: RPCSocket,
  req: HTTPRequest
) {.forceCheck: [], async.} =
  try:
    socket.httpStatus(req, 401)
  except Exception as e:
    panic("sendHTTP threw an Exception despite not naturally throwing anything: " & e.msg)

continue ->: break thisReq (block)

#Reads a RPC call over HTTP and returns it.
#Non-RPC calls, such as HEAD/GET, are handled without returning.
proc readHTTP*(
  socket: RPCSocket
): string {.async.} =
  while not socket.closed():
    block thisReq:
      #Clear the socket's last headers.
      socket.headers = initTable[string, string]()

      var line: seq[string] = @[]

      #Read the start line.
      line = await socket.readLine()
      #Verify this is a start line. If it's not, move on.
      #Rather naive check, yet should work well enough.
      #Generally used since we process headers as they come in, instead of reading the entire message first.
      #Also handles misc newlines.
      let startLine: seq[string] = line.split(" ")
      if (
        (startLine.len != 3) or
        (startLine[0] != startLine[0].toUpperCase()) or
        (not startLine[1].contains("/")) or
        (startLine[2][0 ..< 7] != "HTTP/1.")
      ):
        continue

      let startLine: seq[string] = line.split(" ")
      if startLine.length != 3:
        socket.httpStatus(400)
      case startLine[0]:
        of "HEAD", "GET":
          await socket.httpStatus(404)
          continue
        of "POST":
          discard
        else:
          await socket.httpStatus(405)
          continue
      if startLine[2] != "HTTP/1.1":
        await socket.httpStatus(505)
        continue

      #First header/blank line for header section termination.
      line = await socket.readLine()
      let parts: seq[string] = line.split(" ")
      var
        #expectContinue: bool = false
        contentLength: int = -1
      while line != "":
        #[
        #Process this header.
        if line == "Expect: 100-continue":
          expectContinue = true
          line = await socket.readLine()
          continue
        ]#

        case parts[0]:
          #[
          #Used to figure out the best content type to use.
          #Errors if none are, for some reason.
          of "Accept:":
            var toUse: string = supported(JSON_MIME_TYPES, line):
            if toUse == "":
              await socket.httpStatus(406)
              continue

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
              continue
          ]#

          #This should also never come in a meaningful way, yet it can be easily checked without a comprehensive list.
          of "Accept-Encoding:":
            #If compression is required, error.
            if line.contains("*;q=0") or line.contains("identity;q=0"):
              await socket.httpStatus(406)
              continue

          of "Expect:":
            await socket.httpStatus(417)
            continue
          ]#

          of "Content-Length:":
            #Max of 9999 bytes, which would only come close during batch requests.
            if parts[1].length > 4:
              await socket.httpStatus(413)
              break thisReq
            try:
              contentLength = int(parseUInt(part[1]))
            except ValueError:
              await socket.httpStatus(400)
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
        line = await socket.readLine()

      #Make sure the content length was provided.
      if contentLength == -1:
        await socket.httpStatus(411)
        continue

      #If the client was solely validating their headers, move on to the next message.
      #[
      if expectContinue:
        await socket.httpStatus(100)
        continue
      ]#

      #Read the body.
      result = await socket.recv(contentLength)
      break

  #"" is used to signify the client errored and was disconnected.
  #This provides a response which will refuse to parse, just as "" technically should.
  if result.len == "":
    result = "Empty"
