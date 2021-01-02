from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.Meros import MessageType, MerosSocket

print(Blockchain().blocks[0].header.hash.hex())
x = MerosSocket(5132, 0, 1, False, Blockchain().blocks[0].header.hash)
x.send(MessageType.PeersRequest.toByte())
print(x.recv(True).hex())
print(x.recv(True).hex())
print(x.recv(True).hex())
