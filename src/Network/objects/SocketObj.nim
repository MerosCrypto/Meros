import chronos
export TransportAddress

import ../../lib/Errors

type Socket* = ref object
  stream: StreamTransport
  alreadyClosed: bool

proc newSocket*(
  addy: TransportAddress
): Future[Socket] {.forceCheck: [
  Exception
], async.} =
  try:
    result = Socket(
      stream: await connect(addy),
      alreadyClosed: false
    )
  except Exception as e:
    raise e

proc newSocket*(
  stream: StreamTransport
): Socket {.inline, forceCheck: [].} =
  Socket(
    stream: stream,
    alreadyClosed: false
  )

proc localAddress*(
  socket: Socket
): TransportAddress {.forceCheck: [
  TransportOSError
].} =
  try:
    result = socket.stream.localAddress
  except TransportError as e:
    panic("Trying to handle a socket which isn't a socket: " & e.msg)
  except TransportOSError as e:
    raise e

proc remoteAddress*(
  socket: Socket
): TransportAddress {.forceCheck: [
  TransportOSError
].} =
  try:
    result = socket.stream.remoteAddress
  except TransportError as e:
    panic("Trying to handle a socket which isn't a socket: " & e.msg)
  except TransportOSError as e:
    raise e

proc send*(
  socket: Socket,
  data: string
) {.forceCheck: [
  SocketError
], async.} =
  if socket.isNil:
    raise newLoggedException(SocketError, "Socket is null.")

  try:
    if (await socket.stream.write(data)) != data.len:
      raise newLoggedException(SocketError, "Couldn't send the full message.")
  except SocketError as e:
    raise e
  except Exception as e:
    raise newLoggedException(SocketError, "Couldn't send to this socket: " & e.msg)

proc recv*(
  socket: Socket,
  len: int
): Future[string] {.forceCheck: [
  SocketError
], async.} =
  #Chronos treats length 0 as the entire remaining buffer.
  #We treat 0 as 0.
  if len == 0:
    return
  try:
    result = cast[string](await socket.stream.read(len))
  except Exception as e:
    raise newLoggedException(SocketError, "Couldn't read from this socket: " & e.msg)

proc closed*(
  socket: Socket
): bool {.inline, forceCheck: [].} =
  socket.isNil or socket.alreadyClosed or socket.stream.closed

#Safely close a socket.
proc safeClose*(
  socket: Socket,
  reason: string
) {.forceCheck: [].} =
  if socket.closed:
    return
  socket.alreadyClosed = true

  try:
    socket.stream.close()
  except Exception as e:
    panic("Failed to close a socket: " & e.msg)

  if reason != "":
    logDebug "Closing raw socket", reason = reason
