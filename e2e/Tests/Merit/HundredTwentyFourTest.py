from typing import Dict, List, Any
import json

from e2e.Classes.Merit.Blockchain import Block, Blockchain

from e2e.Meros.RPC import RPC
from e2e.Meros.Meros import MessageType

from e2e.Tests.Errors import TestError
from e2e.Tests.Merit.Verify import verifyBlockchain

#pylint: disable=too-many-statements,too-many-nested-blocks
def HundredTwentyFourTest(
  rpc: RPC
) -> None:
  vectors: List[Dict[str, Any]]
  with open("e2e/Vectors/Merit/BlankBlocks.json", "r") as file:
    vectors = json.loads(file.read())

  blockchain: Blockchain = Blockchain()
  for i in range(2):
    blockchain.add(Block.fromJSON(vectors[i]))

  rpc.meros.liveConnect(blockchain.blocks[0].header.hash)
  rpc.meros.syncConnect(blockchain.blocks[0].header.hash)

  def handleSync() -> None:
    reqHash: bytes = bytes()
    bH: int = 0
    bB: int = 1
    while True:
      if bB == 3:
        break

      msg: bytes = rpc.meros.sync.recv()
      if MessageType(msg[0]) == MessageType.BlockListRequest:
        reqHash = msg[-32:]
        for b in range(len(blockchain.blocks)):
          if blockchain.blocks[b].header.hash == reqHash:
            blockList: List[bytes] = []
            for bl in range(1, msg[2] + 2):
              if b - bl < 0:
                break
              blockList.append(blockchain.blocks[b - bl].header.hash)

            if blockList == []:
              rpc.meros.dataMissing()
              break

            rpc.meros.blockList(blockList)
            break

          if b == len(blockchain.blocks):
            rpc.meros.dataMissing()

      elif MessageType(msg[0]) == MessageType.BlockHeaderRequest:
        reqHash = msg[1 : 33]
        if reqHash != blockchain.blocks[2 - bH].header.hash:
          raise TestError("Meros asked for a Block Header that didn't belong to the next Block.")

        #Send the BlockHeader.
        rpc.meros.syncBlockHeader(blockchain.blocks[2 - bH].header)
        bH += 1

      elif MessageType(msg[0]) == MessageType.BlockBodyRequest:
        reqHash = msg[1 : 33]
        if reqHash != blockchain.blocks[bB].header.hash:
          raise TestError("Meros asked for a Block Body that didn't belong to the next Block.")

        rpc.meros.rawBlockBody(blockchain.blocks[bB], len(blockchain.blocks[bB].body.packets))
        bB += 1

      else:
        raise TestError("Unexpected message sent: " + msg.hex().upper())

    #Verify the Blockchain.
    verifyBlockchain(rpc, blockchain)

  #Send another Handshake with the latest block as the tip.
  rpc.meros.live.send(
    MessageType.Handshake.toByte() +
    (0).to_bytes(1, "little") +
    (127).to_bytes(1, "little") +
    b'\0\0\0' +
    blockchain.last()
  )

  #Verify Meros responds with their tail (the genesis).
  if rpc.meros.live.recv() != MessageType.BlockchainTail.toByte() + blockchain.blocks[0].header.hash:
    raise TestError("Meros didn't respond with the genesis.")

  #Handle the sync.
  handleSync()

  #Reset Meros and do the same with Syncing.
  rpc.reset()

  rpc.meros.syncConnect(blockchain.blocks[0].header.hash)
  rpc.meros.sync.send(
    MessageType.Syncing.toByte() +
    (0).to_bytes(1, "little") +
    (127).to_bytes(1, "little") +
    b'\0\0\0' +
    blockchain.last()
  )
  if rpc.meros.sync.recv() != MessageType.BlockchainTail.toByte() + blockchain.blocks[0].header.hash:
    raise TestError("Meros didn't respond with the genesis.")
  handleSync()
