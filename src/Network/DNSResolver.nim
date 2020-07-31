import ../lib/Errors

import asyncdispatch except async, FutureBase, Future
import asyncnet

import chronos

#Resolve a domain to an IP using the Nim standard library.
proc resolveIPInternal(
  address: string,
  port: int
): chronos.Future[string] {.forceCheck: [].} =
  var ipFuture: chronos.Future[string] = chronos.newFuture[string]("resolveIPInternal")
  result = ipFuture

  var socket: AsyncSocket
  try:
    socket = newAsyncSocket()
  except Exception as e:
    panic("Failed to create a socket: " & e.msg)

  try:
    socket.connect(address, Port(port)).addCallback(
      proc (
        future: asyncdispatch.Future[void]
      ) {.forceCheck: [].} =
        try:
          ipFuture.complete(socket.getPeerAddr()[0])
        except Exception:
          try:
            ipFuture.complete("")
          except Exception as e:
            panic("Couldn't complete a future: " & e.msg)
        finally:
          if not socket.isClosed():
            try:
              socket.close()
            except Exception:
              discard
    )
  except Exception:
    if not socket.isClosed():
      try:
        socket.close()
      except Exception:
        discard

proc resolveIP*(
  address: string,
  port: int
): Future[string] {.forceCheck: [].} =
  proc runStdlibAsync(): Future[void] {.async.} =
    while true:
      try:
        poll(5)
      except ValueError:
        break
      await sleepAsync(20)

  try:
    result = resolveIPInternal(address, port)
    asyncCheck runStdlibAsync()
  except Exception as e:
    panic("Couldm't call resolveIPInternal: " & e.msg)
