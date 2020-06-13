#Simplified chain construction API.
#Automatically handles keeping Merit Holders' Merit Unlocked, unless told otherwise.

from typing import Union, List
from hashlib import blake2b

from e2e.Libs.BLS import PrivateKey, Signature

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Element import Element
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SendDifficulty import SendDifficulty, SignedSendDifficulty
from e2e.Classes.Consensus.DataDifficulty import DataDifficulty, SignedDataDifficulty
from e2e.Classes.Consensus.MeritRemoval import MeritRemoval

from e2e.Classes.Merit.Blockchain import BlockHeader, BlockBody, Block, Blockchain

class GenerationError(
  Exception
):
  pass

def signElement(
  key: PrivateKey,
  elem: Element
) -> Signature:
  if isinstance(elem, SendDifficulty):
    sendDiff: SignedSendDifficulty = SignedSendDifficulty(elem.difficulty, elem.nonce)
    sendDiff.sign(elem.holder, key)
    return sendDiff.signature

  if isinstance(elem, DataDifficulty):
    dataDiff: SignedDataDifficulty = SignedDataDifficulty(elem.difficulty, elem.nonce)
    dataDiff.sign(elem.holder, key)
    return dataDiff.signature

  if isinstance(elem, MeritRemoval):
    return Signature.aggregate([
      signElement(key, elem.e1),
      signElement(key, elem.e2)
    ])

  raise GenerationError("Tried to sign an Element in a Block we didn't recognize the type of.")

#pylint: disable=too-few-public-methods
class PrototypeBlock:
  def __init__(
    self,
    packets: List[VerificationPacket],
    elements: List[Element],
    significant: int,
    minerKey: PrivateKey,
    minerID: Union[bytes, int],
    time: int,
    privateKeys: List[PrivateKey]
  ) -> None:
    #Store all the arguments relevant to this specific Block.
    self.packets: List[VerificationPacket] = packets
    self.elements: List[Element] = elements
    self.significant: int = significant
    self.minerKey: PrivateKey = minerKey
    self.minerID: Union[bytes, int] = minerID
    self.time: int = time

    #Create the signatures for every packet/element.
    signatures: List[Signature] = []
    for packet in self.packets:
      for holder in packet.holders:
        verif: SignedVerification = SignedVerification(packet.hash, holder)
        verif.sign(holder, privateKeys[holder])
        signatures.append(verif.signature)
    for element in self.elements:
      signatures.append(signElement(privateKeys[element.holder], element))

    #Set the aggregate.
    self.aggregate: Signature = Signature.aggregate(signatures)

  def finish(
    self,
    keepUnlocked: bool,
    genesis: bytes,
    prev: BlockHeader,
    diff: int,
    privateKeys: List[PrivateKey]
  ) -> Block:
    if keepUnlocked:
      #Create the Data from the last Block.
      blockData: Data = Data(genesis, prev.hash)

      #Create Verifications for said Data with every Private Key.
      #Ensures no one has their Merit locked.
      #pylint: disable=unnecessary-comprehension
      self.packets.append(VerificationPacket(blockData.hash, [i for i in range(len(privateKeys))]))
      dataSigs: List[Signature] = [self.aggregate]
      for i, privKey in enumerate(privateKeys):
        verif: SignedVerification = SignedVerification(blockData.hash, i)
        verif.sign(i, privKey)
        dataSigs.append(verif.signature)
      self.aggregate = Signature.aggregate(dataSigs)

    #Create the actual Block.
    result: Block = Block(
      BlockHeader(
        0,
        prev.hash,
        BlockHeader.createContents(self.packets, self.elements),
        self.significant,
        bytes(4),
        BlockHeader.createSketchCheck(bytes(4), self.packets),
        self.minerID,
        self.time
      ),
      BlockBody(self.packets, self.elements, self.aggregate)
    )
    result.mine(self.minerKey, diff)
    return result

blankUnlockedInternal: Blockchain
blankLockedInternal: Blockchain

class PrototypeChain:
  def __init__(
    self,
    blankBlocks: int = 0,
    keepUnlocked: bool = True,
    timeOffset: int = 1200
  ) -> None:
    self.blankBlocks: int = blankBlocks
    self.keepUnlocked: bool = keepUnlocked
    self.timeOffset: int = timeOffset
    self.minerKeys: List[PrivateKey] = []
    self.blocks: List[PrototypeBlock] = []

  @staticmethod
  def blankUnlocked() -> Blockchain:
    return blankUnlockedInternal

  @staticmethod
  def blankLocked() -> Blockchain:
    return blankLockedInternal

  def add(
    self,
    nick: int = 0,
    packets: List[VerificationPacket] = [],
    elements: List[Element] = []
  ) -> None:
    #Determine if this is a new miner or not.
    miner: Union[bytes, int]
    if nick >= len(self.minerKeys):
      raise GenerationError("Told to mine a Block with a miner nick which doesn't exist.")
    if nick == len(self.minerKeys):
      #If it is, generate the relevant key.
      self.minerKeys.append(PrivateKey(blake2b(nick.to_bytes(2, "big"), digest_size=32).digest()))
      miner = self.minerKeys[-1].toPublicKey().serialize()
    else:
      miner = nick

    timeBase: int
    if len(self.blocks) == 0:
      #It doesn't matter if we use unlocked or locked; they share timestamps.
      #If no blank Blocks are used, this returns the genesis time which should be the base anyways.
      timeBase = blankUnlockedInternal.blocks[self.blankBlocks].header.time
    else:
      timeBase = self.blocks[-1].time

    #Create and add the PrototypeBlock.
    self.blocks.append(
      PrototypeBlock(
        #Create copies of the lists used as arguments to ensure we don't mutate the arguments.
        list(packets),
        list(elements),
        1,
        self.minerKeys[nick],
        miner,
        timeBase + self.timeOffset,
        self.minerKeys
      )
    )

  def finish(
    self
  ) -> Blockchain:
    blockchain: Blockchain = Blockchain()

    #Add the blank Blocks.
    for b in range(1, self.blankBlocks + 1):
      if self.keepUnlocked:
        blockchain.add(blankUnlockedInternal.blocks[b])
      else:
        blockchain.add(blankLockedInternal.blocks[b])

    #Mine and append each Block.
    for block in self.blocks:
      blockchain.add(
        block.finish(
          self.keepUnlocked,
          blockchain.genesis,
          blockchain.blocks[-1].header,
          blockchain.difficulty(),
          self.minerKeys
        )
      )

    return blockchain

#Create 25 Blank Blocks to be used through out vectors which require a count of Blocks from the start.
protoBlankUnlocked: PrototypeChain = PrototypeChain()
protoBlankLocked: PrototypeChain = PrototypeChain(keepUnlocked=False)
for _ in range(25):
  protoBlankUnlocked.add()
  protoBlankLocked.add()
blankUnlockedInternal = protoBlankUnlocked.finish()
blankLockedInternal = protoBlankLocked.finish()
