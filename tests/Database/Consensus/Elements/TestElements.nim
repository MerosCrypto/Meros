import random

import ../../../../src/lib/[Util, Hash]
import ../../../../src/Wallet/MinerWallet

import ../../../../src/Database/Consensus/Elements/Elements
export Elements

import ../../../Fuzzed

proc newRandomVerification*(
  holder: uint16 = uint16(rand(high(int16)))
): SignedVerification =
  var
    hash: Hash[256] = newRandomHash()
    miner: MinerWallet = newMinerWallet()
  miner.nick = holder

  result = newSignedVerificationObj(hash)
  miner.sign(result)

proc newRandomVerificationPacket*(
  holder: uint16 = uint16(rand(high(int16))),
  hash: Hash[256] = newRandomHash()
): SignedVerificationPacket =
  var miner: MinerWallet = newMinerWallet()

  result = newSignedVerificationPacketObj(hash)

  #Randomize the participating holders.
  for h in 0 ..< rand(500) + 1:
    if h == 0:
      result.holders.add(holder)
    else:
      result.holders.add(uint16(rand(high(int16))))

  #Set a random signature.
  result.signature = miner.sign("")

proc newRandomSendDifficulty*(
  holder: uint16 = uint16(rand(high(int16)))
): SignedSendDifficulty =
  var
    nonce: int = rand(high(int32))
    difficulty: uint32 = uint32(rand(high(int32)))
    miner: MinerWallet = newMinerWallet()
  miner.nick = holder

  result = newSignedSendDifficultyObj(nonce, difficulty)
  miner.sign(result)

proc newRandomDataDifficulty*(
  holder: uint16 = uint16(rand(high(int16)))
): SignedDataDifficulty =
  var
    nonce: int = rand(high(int32))
    difficulty: uint32 = uint32(rand(high(int32)))
    miner: MinerWallet = newMinerWallet()
  miner.nick = holder

  result = newSignedDataDifficultyObj(nonce, difficulty)
  miner.sign(result)

proc newRandomMeritRemoval*(
  holder: uint16 = uint16(rand(high(int16)))
): SignedMeritRemoval

proc newRandomElement*(
  holder: uint16 = uint16(rand(high(int16))),
  verification: bool = true,
  packet: bool = true,
  sendDifficulty: bool = true,
  dataDifficulty: bool = true,
  gasPrice: bool = true,
  removal: bool = true
): Element =
  var
    possibilities: set[int8] = {}
    r: int8 = int8(rand(5))

  #Include all possibilities in the set.
  if verification: possibilities.incl(0)
  if packet: possibilities.incl(1)
  if sendDifficulty: possibilities.incl(2)
  if dataDifficulty: possibilities.incl(3)
  #if gasPrice: possibilities.incl(4)
  if removal: possibilities.incl(5)

  #Until r is a valid possibility, randomize it.
  while not (r in possibilities):
    r = int8(rand(5))

  case r:
    of 0: result = newRandomVerification(holder)
    of 1: result = newRandomVerificationPacket(holder)
    of 2: result = newRandomSendDifficulty(holder)
    of 3: result = newRandomDataDifficulty(holder)
    of 4: discard
    of 5: result = newRandomMeritRemoval()
    else: check false

proc newRandomMeritRemoval*(
  holder: uint16 = uint16(rand(high(int16)))
): SignedMeritRemoval =
  var
    partial: bool = rand(1) == 0
    e1: Element = newRandomElement(holder = holder, removal = false)
    e2: Element = newRandomElement(holder = holder, removal = false)
    signatures: seq[BLSSignature] = @[]
    lookup: seq[BLSPublicKey] = newSeq[BLSPublicKey](65536)

  if e1 of VerificationPacket:
    for holder in cast[VerificationPacket](e1).holders:
      lookup[int(holder)] = newMinerWallet().publicKey
  if e2 of VerificationPacket:
    for holder in cast[VerificationPacket](e2).holders:
      lookup[int(holder)] = newMinerWallet().publicKey

  if not partial:
    case e1:
      of Verification as verif:
        signatures.add(cast[SignedVerification](verif).signature)
      of VerificationPacket as vp:
        signatures.add(cast[SignedVerificationPacket](vp).signature)
      of SendDifficulty as sd:
        signatures.add(cast[SignedSendDifficulty](sd).signature)
      of DataDifficulty as dd:
        signatures.add(cast[SignedDataDifficulty](dd).signature)
      #of GasPrice as gp:
      #  signatures.add(cast[SignedGasPrice](gp).signature)
      of MeritRemoval as mr:
        check false
      else:
        check false

  case e2:
    of Verification as verif:
      signatures.add(cast[SignedVerification](verif).signature)
    of VerificationPacket as vp:
      signatures.add(cast[SignedVerificationPacket](vp).signature)
    of SendDifficulty as sd:
      signatures.add(cast[SignedSendDifficulty](sd).signature)
    of DataDifficulty as dd:
      signatures.add(cast[SignedDataDifficulty](dd).signature)
    #of GasPrice as gp:
    #  signatures.add(cast[SignedGasPrice](gp).signature)
    of MeritRemoval as mr:
      check false
    else:
      check false

  result = newSignedMeritRemoval(
    holder,
    partial,
    e1,
    e2,
    signatures.aggregate(),
    lookup
  )

proc newRandomBlockElement*(
  sendDifficulty: bool = true,
  dataDifficulty: bool = true,
  gasPrice: bool = true,
  removal: bool = true
): BlockElement =
  var
    possibilities: set[int8] = {}
    r: int8 = int8(rand(3))

  #Include all possibilities in the set.
  if sendDifficulty: possibilities.incl(0)
  if dataDifficulty: possibilities.incl(1)
  #if gasPrice: possibilities.incl(2)
  if removal: possibilities.incl(3)

  #Until r is a valid possibility, randomize it.
  while not (r in possibilities):
    r = int8(rand(3))

  case r:
    of 0: result = newRandomSendDifficulty()
    of 1: result = newRandomDataDifficulty()
    of 2: discard
    of 3: result = newRandomMeritRemoval()
    else: check false
