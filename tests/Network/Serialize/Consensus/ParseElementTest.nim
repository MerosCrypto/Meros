#[
Parse Element Test.
ParseElement only has one function; getLength.
This test tests every single case getLength may have to handle.

SendDifficulty
DataDifficulty

MeritRemoval V/*
MeritRemoval SD/*
MeritRemoval DD/*
]#

import random

import ../../../../src/lib/Util
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

    for first in 0 ..< 3:
      var
        e1: Element
        holder: uint16 = uint16(rand(high(int16)))
      case first:
        of 0:
          e1 = newRandomVerification(holder)
        of 1:
          e1 = newRandomSendDifficulty(holder)
        of 2:
          e1 = newRandomDataDifficulty(holder)
        else:
          raise newException(Exception, "Impossible case executed.")

      for second in 0 ..< 3:
        var e2: Element
        case second:
          of 0:
            e2 = newRandomVerification(holder)
          of 1:
            e2 = newRandomSendDifficulty(holder)
          of 2:
            e2 = newRandomDataDifficulty(holder)
          else:
            raise newException(Exception, "Impossible case executed.")

        var mr: SignedMeritRemoval = newSignedMeritRemovalObj(
          holder,
          rand(1) == 0,
          e1,
          e2,
          newMinerWallet().sign("")
        )

        var len: int = NICKNAME_LEN + BYTE_LEN
        for _ in 0 ..< 2:
          len += MERIT_REMOVAL_ELEMENT_SET.getLength(
            mr.serialize()[len],
            mr.serialize()[len + 1 .. len].fromBinary(),
            MERIT_REMOVAL_PREFIX
          )
        len += BLS_SIGNATURE_LEN
        check mr.serialize().len == len
