from typing import Deque, Dict, List, Tuple, Optional
from collections import deque

from e2e.Classes.Transactions.Mint import Mint
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain
from e2e.Classes.Merit.State import State

class Epochs:
  def __init__(
    self
  ) -> None:
    self.epochs: Deque[Dict[bytes, List[int]]] = deque([{}] * 5)
    self.mint: int = 0

  @staticmethod
  def reward(
    blockHash: bytes,
    scores: List[Tuple[int, int]]
  ) -> Optional[Mint]:
    outputs: List[Tuple[int, int]] = []
    for score in scores:
      if score[1] == 0:
        break
      outputs.append((score[0], score[1] * 50))
    return Mint(blockHash, outputs)

  #Score an Epoch and generate rewards.
  @staticmethod
  def score(
    state: State,
    blockHash: bytes,
    epoch: Dict[bytes, List[int]]
  ) -> Optional[Mint]:
    #Grab the verified Transactions.
    verified: List[bytes] = []
    for tx in epoch:
      merit: int = 0
      for holder in epoch[tx]:
        merit += state.unlocked[holder]
      if merit >= state.merit // 2 + 1:
        verified.append(tx)

    if not verified:
      return None

    #Assign each Merit Holder 1 point per verified transaction.
    scores: Dict[int, int] = {}
    for tx in verified:
      for holder in epoch[tx]:
        if not holder in scores:
          scores[holder] = 0
        scores[holder] += 1

    #Multiply each Merit Holder's score by their weight.
    total: int = 0
    tupleScores: List[Tuple[int, int]] = []
    for holder in scores:
      score: int = scores[holder] * state.unlocked[holder]
      total += score
      tupleScores.append((holder, score))

    #Sort the scores and remove trailing scores.
    tupleScores.sort(key=lambda tup: (-tup[1], tup[0]))
    for i in range(100, len(tupleScores)):
      del tupleScores[i]

    #Normalize the scores to 1000.
    for i in range(len(tupleScores)):
      tupleScores[i] = (tupleScores[i][0], tupleScores[i][1] * 1000 // total)

    #Make sure we have a total of 1000 by giving the edge to the top score.
    total = 0
    for tupleScore in tupleScores:
      total += tupleScore[1]
    tupleScores[0] = (tupleScores[0][0], tupleScores[0][1] + (1000 - total))

    #Create Mints.
    return Epochs.reward(blockHash, tupleScores)

  #Shift on a Block, creating a Mint out of the oldest Epoch.
  def shift(
    self,
    state: State,
    blockchain: Blockchain,
    b: int
  ) -> Optional[Mint]:
    block: Block = blockchain.blocks[b]

    #Construct the new Epoch.
    epoch: Dict[bytes, List[int]] = {}
    for packet in block.body.packets:
      found: bool = False
      for e in range(len(self.epochs)):
        if packet.hash in self.epochs[e]:
          found = True
          self.epochs[e][packet.hash] += packet.holders

      if not found:
        if packet.hash not in epoch:
          epoch[packet.hash] = []
        epoch[packet.hash] += packet.holders

    self.epochs.append(epoch)
    epoch = self.epochs.popleft()

    #Score the Epoch, which creates a Mint and returns it.
    return Epochs.score(state, block.header.hash, epoch)
