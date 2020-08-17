#[
Parse Element Test.
ParseElement only has one function; getLength.
This test tests every single case getLength may have to handle.

SendDifficulty
DataDifficulty

MeritRemoval V/*
MeritRemoval VP/*
MeritRemoval SD/*
MeritRemoval DD/*
]#

import random

import ../../../../src/lib/[Util, Hash]
import ../../../../src/Wallet/MinerWallet

import ../../../../src/Network/Serialize/SerializeCommon
import ../../../../src/Network/Serialize/Consensus/[
  SerializeSendDifficulty,
  SerializeDataDifficulty,
  SerializeMeritRemoval,
  ParseElement
]

import ../../../Fuzzed
import ../../../Database/Consensus/Elements/TestElements

suite "ParseElement":
  noFuzzTest "Serialization.":
    var
      sendDiff: SendDifficulty = newRandomSendDifficulty()
      dataDiff: DataDifficulty = newRandomDataDifficulty()

    check:
      sendDiff.serialize().len == {
        byte(SEND_DIFFICULTY_PREFIX)
      }.getLength(char(SEND_DIFFICULTY_PREFIX))

      dataDiff.serialize().len == {
        byte(DATA_DIFFICULTY_PREFIX)
      }.getLength(char(DATA_DIFFICULTY_PREFIX))

    for first in 0 ..< 5:
      var
        e1: Element
        holder: uint16 = uint16(rand(high(int16)))
      case first:
        of 0:
          e1 = newRandomVerification(holder)
        of 1:
          var mrvp: MeritRemovalVerificationPacket = newMeritRemovalVerificationPacketObj(newRandomHash())
          for h in 0 ..< rand(500):
            mrvp.holders.add(newMinerWallet().publicKey)

          e1 = mrvp
        of 2:
          e1 = newRandomSendDifficulty(holder)
        of 3:
          e1 = newRandomDataDifficulty(holder)
        of 4:
          continue
        else:
          raise newException(Exception, "Impossible case executed.")

      for second in 0 ..< 5:
        var e2: Element
        case second:
          of 0:
            e2 = newRandomVerification(holder)
          of 1:
            var mrvp: MeritRemovalVerificationPacket = newMeritRemovalVerificationPacketObj(newRandomHash())
            for h in 0 ..< rand(500):
              mrvp.holders.add(newMinerWallet().publicKey)
            e2 = mrvp
          of 2:
            e2 = newRandomSendDifficulty(holder)
          of 3:
            e2 = newRandomDataDifficulty(holder)
          of 4:
            continue
          else:
            raise newException(Exception, "Impossible case executed.")

        var mr: MeritRemoval = newMeritRemovalObj(
          holder,
          rand(1) == 0,
          e1,
          e2,
          Hash[256]()
        )

        var
          len: int = {
            byte(MERIT_REMOVAL_PREFIX)
          }.getLength(char(MERIT_REMOVAL_PREFIX))
          eLen: int
        dec(len)

        for _ in 0 ..< 2:
          eLen = 0
          if int(mr.serialize()[len]) == VERIFICATION_PACKET_PREFIX:
            eLen = {
              byte(VERIFICATION_PACKET_PREFIX)
            }.getLength(char(VERIFICATION_PACKET_PREFIX))

          len += MERIT_REMOVAL_ELEMENT_SET.getLength(
            mr.serialize()[len],
            mr.serialize()[len + 1 .. len + eLen].fromBinary(),
            MERIT_REMOVAL_PREFIX
          ) + eLen

        check mr.serialize().len == len
