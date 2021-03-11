from typing import List
import socket

from e2e.Meros.Meros import Meros

from e2e.Tests.Errors import TestError

REQUEST: List[str] = [
  "POST / HTTP/1.1",
  "Accept: */*",
  "Content-Length: 59",
  "Content-Type: application/x-www-form-urlencoded",
  "",
  """{"jsonrpc": "2.0", "id": null, "method": "merit_getHeight"}"""
]

#Doesn't support \r line endings.
def readLine(
  conn: socket.socket
) -> str:
  res: str = conn.recv(1).decode()
  while res[-1] != "\n":
    res += conn.recv(1).decode()
  res = res[:-1]

  #Support \r\n.
  if res[-1] == "\r":
    res = res[:-1]

  return res

def NewLineTest(
  meros: Meros
) -> None:
  for ending in ["\r", "\n", "\r\n"]:
    conn: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    conn.connect(("127.0.0.1", meros.rpc))
    conn.send(ending.join(REQUEST).encode())

    if readLine(conn) != "HTTP/1.1 200 OK":
      raise TestError("Meros didn't respond with 200 OK.")
    conn.close()
