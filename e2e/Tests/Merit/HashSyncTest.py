from typing import Dict, List, Any
import json

from e2e.Classes.Merit.Blockchain import Blockchain, Block
from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Meros.Meros import MessageType

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Meros.Syncer import Syncer

from e2e.Tests.Errors import TestError, SuccessError

def HashSyncTest(
  rpc: RPC
) -> None:
  # Load test blocks.
  vectors: List[Dict[str, Any]]
  with open("e2e/Vectors/Merit/BlankBlocks.json", "r") as file:
    vectors = json.loads(file.read())
  
  amount: int = 25
  # Prep the expected response.
  blockchain: Blockchain = Blockchain().fromJSON(vectors)
  quantity: bytes = (amount-1).to_bytes(1, byteorder="little")
  hashes: bytes = [block.header.hash for block in blockchain.blocks[:amount]]
  desiredResponse: bytes = quantity + b''.join([hash for hash in reversed(hashes)])
  
  def recHash() -> None:
    rpc.meros.syncConnect(blockchain.last())
    rpc.meros.blockListRequest(amount+1, blockchain.blocks[amount].header.hash)
    blockList: bytes = rpc.meros.sync.recv()
    if blockList[1:] != desiredResponse:
      raise TestError('Meros returned a different block list than expected in response to a BlockListRequest.')
  
  def genesisMissing() -> None:
    rpc.meros.syncConnect(blockchain.last())
    rpc.meros.blockListRequest(1, blockchain.blocks[0].header.hash)
    blockList: bytes = rpc.meros.sync.recv()
    print(f'Expecting: {MessageType.DataMissing.toByte()}')
    print(f'Received from Meros: {blockList} (hex: {blockList.hex()})')
    if blockList[1:] != MessageType.DataMissing.toByte():
      raise TestError('Meros did not return a DataMissing response to a BlockListRequest of the block before genesis.')

  liver : Liver = Liver(rpc, vectors, callbacks={3: genesisMissing, amount: recHash}).live()

def print_all_info(
  item: Any,
  pre_name: str = ''
) -> None:

  if type(item) is list:
    i : int = 0
    for subitem in item:
      print_all_info(subitem, pre_name=f'{pre_name}[{i}]')
      i += 1

      if i > 2:
        print(f'{pre_name} has {len(item)} more, not shown.')
        break

  if not hasattr(item, '__dict__'):
    return
  
  print(f'{pre_name}.__dict__:')
  print(item.__dict__)
  for subitem_name, subitem in item.__dict__.items():
    print_all_info(subitem, pre_name=f'{pre_name}.{subitem_name}')