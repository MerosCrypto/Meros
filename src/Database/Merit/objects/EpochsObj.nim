import sequtils
import deques
import tables

import ../../../lib/[Errors, Util, Hash]

import ../../Consensus/Elements/objects/VerificationPacketObj

type
  Reward* = object
    nick*: uint16
    score*: uint64

  #Epoch object. Simply, a table of Transaction Hash -> Nicks of verifiers.
  Epoch* = Table[Hash[256], seq[uint16]]

  #Epochs. Simply, again, a queue of the current 5 Epochs.
  Epochs* = Deque[Epoch]

func newReward*(
  nick: uint16,
  score: uint64
): Reward {.inline, forceCheck: [].} =
  Reward(
    nick: nick,
    score: score
  )

func newEpoch*(): Epoch {.inline, forceCheck: [].} =
  initTable[Hash[256], seq[uint16]]()

func newEpochsObj*(): Epochs {.forceCheck: [].} =
  result = initDeque[Epoch](8)
  for _ in 0 ..< 5:
    result.addLast(newEpoch())

func register*(
  epoch: var Epoch,
  hash: Hash[256]
) {.inline, forceCheck: [].} =
  epoch[hash] = @[]

proc add*(
  epoch: var Epoch,
  packet: VerificationPacket
) {.forceCheck: [].} =
  try:
    epoch[packet.hash] = epoch[packet.hash].concat(packet.holders)
  except KeyError as e:
    panic("Adding a packet to an Epoch which doesn't have that hash registered: " & e.msg)

#Push on a new Epoch while popping the oldest one.
proc shift*(
  epochs: var Epochs,
  epoch: Epoch
): Epoch {.forceCheck: [].} =
  epochs.addLast(epoch)
  try:
    result = epochs.popFirst()
  except IndexError as e:
    panic("Tried to pop an Epoch yet there wasn't any; there should always be 5: " & e.msg)

func latest*(
  epochs: Epochs
): Epoch {.forceCheck: [].} =
  try:
    result = epochs.peekLast()
  except IndexError as e:
    panic("Tried to peek the latest Epoch yet there wasn't any; there should always be 5: " & e.msg)
