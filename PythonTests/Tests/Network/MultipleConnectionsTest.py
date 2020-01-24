#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#RPC class.
from PythonTests.Meros.RPC import RPC

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Sleep standard function.
from time import sleep

#Socket standard libs.
import socket
from socketserver import TCPServer, BaseRequestHandler

def MultipleConnectionsTest(
    rpc: RPC
) -> None:
    #Blockchain. Solely used to get the genesis Block hash.
    blockchain: Blockchain = Blockchain()

    #Handshake with the node.
    rpc.meros.connect(254, 254, blockchain.blocks[0].header.hash)

    #Create new sockets and try connecting.
    for _ in range(3):
        connection: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        connection.connect(("127.0.0.1", rpc.meros.tcp))
        sleep(1)

        try:
            connection.send(b"")
            raise TestError("Meros didn't close our repeat connection.")
        except Exception:
            pass

    for _ in range(2):
        #Close the original connection and wait 30 seconds for Meros to realize it's closed.
        rpc.meros.connection.close()
        sleep(30)

        rpc.meros.connection = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        rpc.meros.connection.connect(("127.0.0.1", rpc.meros.tcp))
        sleep(1)

        #Verify the connection is open.
        try:
            rpc.meros.connection.send(b"")
        except Exception:
            raise TestError("Meros didn't allow our connection after closing the original connection.")

    #Close the original connection again.
    rpc.meros.connection.close()
    sleep(30)

    #Spawn a server socket on port 5131.
    class TCPHandler(
        BaseRequestHandler
    ):
        first: bool = True

        def handle(
            self
        ) -> None:
            sleep(1)

            try:
                connection.send(b"")
                if not self.first:
                    raise Exception("Meros accepted the same connection twice.")
            except Exception:
                if self.first:
                    raise Exception("Meros closed an original connection.")

            self.first = not self.first

    server: TCPServer = TCPServer(("127.0.0.1", 5131), TCPHandler)

    rpc.call("network", "connect", ["127.0.0.1", 5131])
    rpc.call("network", "connect", ["127.0.0.1", 5131])

    server.server_close()
