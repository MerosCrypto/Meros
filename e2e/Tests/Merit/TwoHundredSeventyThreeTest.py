from typing import Dict, Any

from select import select
import json

from e2e.Classes.Merit.Blockchain import BlockHeader, Blockchain

from e2e.Meros.Meros import MessageType, Meros

from e2e.Tests.Errors import TestError

def TwoHundredSeventyThreeTest(
  meros: Meros
) -> None:
  blockchain: Blockchain = Blockchain()

  vectors: Dict[str, Any]
  with open("e2e/Vectors/Merit/TwoHundredSeventyThree.json", "r") as file:
    vectors = json.loads(file.read())
  header: BlockHeader = BlockHeader.fromJSON(vectors)

  meros.liveConnect(blockchain.last())
  meros.syncConnect(blockchain.last())

  #Sanity check on the behavior of select.
  readable, _, _ = select([meros.live.connection, meros.sync.connection], [], [], 65)
  if len(readable) != 1:
    raise Exception("Misuse of select; multiple sockets reported readable.")
  if MessageType(meros.live.recv()[0]) != MessageType.Handshake:
    raise Exception("Misuse of select; it didn't return the live socket trying to Handshake. Keep-alives could also be broken.")
  meros.live.send(MessageType.BlockchainTail.toByte() + blockchain.last())

  #Send the header.
  meros.liveBlockHeader(header)

  #Meros should disconnect us immediately. If it doesn't, it'll either send a keep-alive or a BlockBodyRequest.
  #One is inefficient as it doesn't properly protect against spam attacks.
  #One is invalid completely.
  readable, _, _ = select([meros.live.connection, meros.sync.connection], [], [], 65)
  #On Linux, both sockets immediately appear as readable.
  #That is why we iterate, instead of just checking length == 0.
  for s in readable:
    try:
      temp: str = s.recv(1)
      if len(temp) != 0:
        raise TestError("Meros tried to send us something instead of immediately disconnecting us.")
    except TestError as e:
      raise e
    except Exception:
      pass
