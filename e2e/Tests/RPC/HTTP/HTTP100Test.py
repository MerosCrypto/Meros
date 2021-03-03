import socket
import json

from e2e.Meros.Meros import Meros

from e2e.Tests.Errors import TestError

CURL_100_CONTINUE: str = """POST / HTTP/1.1
Host: 127.0.0.1:5133
User-Agent: curl/7.75.0
Accept: */*
Content-Length: 59
Content-Type: application/x-www-form-urlencoded
Expect: 100-continue\r\n\r\n"""

def readLine(
  conn: socket.socket
) -> str:
  res: str = conn.recv(1).decode()
  #Doesn't support \r line endings.
  while res[-1] != "\n":
    res += conn.recv(1).decode()
  res = res[:-1]

  #Support \r\n.
  if res[-1] == "\r":
    res = res[:-1]

  return res

def HTTP100Test(
  meros: Meros
) -> None:
  conn: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  conn.connect(("127.0.0.1", meros.rpc))
  conn.send(CURL_100_CONTINUE.encode())

  res: str = ""
  last: str = " "
  while last != "":
    last = readLine(conn)
    res += last + "\n"

  if res.split("\n")[0] != "HTTP/1.1 100 Continue":
    raise TestError("Meros didn't respond with 100 Continue.")

  conn.send(b"""{"jsonrpc": "2.0", "id": null, "method": "merit_getHeight"}""")

  res = ""
  last = " "
  contentLength: int = -1
  while last != "":
    last = readLine(conn)
    if last.startswith("Content-Length"):
      contentLength = int(last.split(" ")[1])
    res += last + "\n"

  if res.split("\n")[0] != "HTTP/1.1 200 OK":
    raise TestError("Meros didn't respond with 200 OK.")
  if json.loads(conn.recv(contentLength).decode()) != {
    "jsonrpc": "2.0",
    "id": None,
    "result": 1
  }:
    raise TestError("Meros didn't respond to our request.")
