#Simplified chain construction API.
#Automatically handles keeping Merit Holders' Merit Unlocked, unless told otherwise.

from typing import Union, Dict, List, Any

from e2e.Libs.BLS import PrivateKey, Signature

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Element import Element
from e2e.Classes.Consensus.Verification import Verification, SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SendDifficulty import SendDifficulty, SignedSendDifficulty
from e2e.Classes.Consensus.DataDifficulty import DataDifficulty, SignedDataDifficulty

from e2e.Classes.Merit.Blockchain import BlockHeader, BlockBody, Block, Blockchain
from e2e.Classes.Merit.Merit import Merit

class GenerationError(
  Exception
):
  pass

def signElement(
  elem: Element
) -> Signature:
  if isinstance(elem, Verification):
    verif: SignedVerification = SignedVerification(elem.hash, elem.holder)
    verif.sign(elem.holder, PrivateKey(elem.holder))
    return verif.signature
  if isinstance(elem, SendDifficulty):
    sendDiff: SignedSendDifficulty = SignedSendDifficulty(elem.difficulty, elem.nonce)
    sendDiff.sign(elem.holder, PrivateKey(elem.holder))
    return sendDiff.signature
  if isinstance(elem, DataDifficulty):
    dataDiff: SignedDataDifficulty = SignedDataDifficulty(elem.difficulty, elem.nonce)
    dataDiff.sign(elem.holder, PrivateKey(elem.holder))
    return dataDiff.signature

  raise GenerationError("Tried to sign an Element in a Block we didn't recognize the type of.")

#pylint: disable=too-few-public-methods
class PrototypeBlock:
  def __init__(
    self,
    time: int,
    packets: List[VerificationPacket] = [],
    elements: List[Element] = [],
    significant: int = 1,
    minerID: Union[PrivateKey, int] = 0
  ) -> None:
    #Store all the arguments relevant to this specific Block.
    self.packets: List[VerificationPacket] = list(packets)
    self.elements: List[Element] = list(elements)
    self.significant: int = significant
    self.minerID: Union[PrivateKey, int] = minerID
    self.time: int = time

  #pylint: disable=too-many-locals
  def finish(
    self,
    keepUnlocked: int,
    existing: Merit
  ) -> Block:
    genesis: bytes = existing.blockchain.genesis
    prev: BlockHeader = existing.blockchain.blocks[-1].header
    diff: int = existing.blockchain.difficulty()

    #Create the signatures for every packet/element.
    signatures: List[Signature] = []
    for packet in self.packets:
      for holder in packet.holders:
        verif: SignedVerification = SignedVerification(packet.hash, holder)
        verif.sign(holder, PrivateKey(holder))
        signatures.append(verif.signature)
    for element in self.elements:
      signatures.append(signElement(element))

    #Only add the Data Verification if:
    #1) We're supposed to make sure Merit Holders are always Unlocked
    #2) The last Block created a Data
    #3) The Merit Holder has Merit.
    if (keepUnlocked != 0) and (prev.last != genesis):
      #Create the Data from the last Block.
      blockData: Data = Data(genesis, prev.hash)

      #Create Verifications for said Data with every Private Key.
      #Ensures no one has their Merit locked.
      #pylint: disable=unnecessary-comprehension
      self.packets.append(VerificationPacket(blockData.hash, []))
      for i in range(keepUnlocked):
        if (
          #Miners who are just being created don't have Merit.
          ((i == (keepUnlocked - 1)) and (isinstance(self.minerID, PrivateKey))) or
          (existing.state.balances[i] == 0)
        ):
          continue

        self.packets[-1].holders.append(i)
        verif: SignedVerification = SignedVerification(blockData.hash, i)
        verif.sign(i, PrivateKey(i))
        signatures.append(verif.signature)

      #Remove this packet if there's no holders.
      if not self.packets[-1].holders:
        del self.packets[-1]

    #Set the aggregate.
    aggregate = Signature.aggregate(signatures)

    #Create the actual Block.
    minerID: Union[bytes, int] = 0
    if isinstance(self.minerID, int):
      minerID = self.minerID
    else:
      minerID = self.minerID.toPublicKey().serialize()

    result: Block = Block(
      BlockHeader(
        0,
        prev.hash,
        BlockHeader.createContents(self.packets, self.elements),
        self.significant,
        bytes(4),
        BlockHeader.createSketchCheck(bytes(4), self.packets),
        minerID,
        self.time
      ),
      BlockBody(self.packets, self.elements, aggregate)
    )
    if isinstance(self.minerID, int):
      result.mine(PrivateKey(self.minerID), diff)
    else:
      result.mine(self.minerID, diff)
    return result

class PrototypeChain:
  timeOffset: int
  miners: List[int]
  blocks: List[PrototypeBlock]

  def add(
    self,
    nick: int = 0,
    packets: List[VerificationPacket] = [],
    elements: List[Element] = []
  ) -> None:
    #Determine if this is a new miner or not.
    miner: Union[PrivateKey, int]
    self.miners.append(self.miners[-1])
    if nick > self.miners[-1]:
      raise GenerationError("Told to mine a Block with a miner nick which doesn't exist.")
    if nick == self.miners[-1]:
      miner = PrivateKey(nick)
      self.miners[-1] += 1
    else:
      miner = nick

    timeBase: int
    if len(self.blocks) == 0:
      timeBase = Blockchain().blocks[0].header.time
    else:
      timeBase = self.blocks[-1].time

    #Create and add the PrototypeBlock.
    self.blocks.append(
      PrototypeBlock(
        timeBase + self.timeOffset,
        #Create copies of the lists used as arguments to ensure we don't mutate the arguments.
        list(packets),
        list(elements),
        1,
        miner
      )
    )

  def __init__(
    self,
    blankBlocks: int = 0,
    keepUnlocked: bool = True,
    timeOffset: int = 1200
  ) -> None:
    self.keepUnlocked: bool = keepUnlocked
    self.timeOffset = timeOffset
    self.miners = [0]
    self.blocks = []

    for _ in range(blankBlocks):
      self.add()

  def finish(
    self
  ) -> Blockchain:
    actual: Merit = Merit()

    for b in range(len(self.blocks)):
      actual.add(
        self.blocks[b].finish(
          self.miners[b] if self.keepUnlocked else 0,
          actual
        )
      )

    return actual.blockchain

  def toJSON(
    self
  ) -> List[Dict[str, Any]]:
    return self.finish().toJSON()

  @staticmethod
  def withMint() -> Merit:
    #Create a Mint by mining 8 Blank Blocks.
    #The first grants Merit; the second creates a Data; the third verifies the Data.
    #The next 5 finalize the Data.
    result: Merit = Merit.fromJSON(PrototypeChain(7).toJSON())
    if len(result.mints) != 1:
      raise GenerationError("PrototypeChain Mint generator didn't create a Mint.")
    return result
