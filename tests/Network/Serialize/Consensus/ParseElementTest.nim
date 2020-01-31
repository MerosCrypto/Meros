#[
Parse Element Test.
ParseElement only has one function; getLength.
This test tests every single case getLength may have to handle.

SendDifficulty
DataDifficulty
GasPrice

MeritRemoval V/*
MeritRemoval VP/*
MeritRemoval SD/*
MeritRemoval DD/*
MeritRemoval GP/*
]#

#Test lib.
import unittest

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Elements Testing lib.
import ../../../Database/Consensus/Elements/TestElements

#Serialization libs.
import ../../../../src/Network/Serialize/SerializeCommon
import ../../../../src/Network/Serialize/Consensus/ParseElement
#import ../../../../src/Network/Serialize/Consensus/SerializeSendDifficulty
import ../../../../src/Network/Serialize/Consensus/SerializeDataDifficulty
#import ../../../../src/Network/Serialize/Consensus/SerializeGasPrize
import ../../../../src/Network/Serialize/Consensus/SerializeMeritRemoval

#Random standard lib.
import random

suite "ParseElement":
    test "Serialization.":
        var sendDiff: SendDifficulty = newRandomSendDifficulty()
        check(sendDiff.serialize().len == {
            uint8(SEND_DIFFICULTY_PREFIX)
        }.getLength(char(SEND_DIFFICULTY_PREFIX)))

        var dataDiff: DataDifficulty = newRandomDataDifficulty()
        check(dataDiff.serialize().len == {
            uint8(DATA_DIFFICULTY_PREFIX)
        }.getLength(char(DATA_DIFFICULTY_PREFIX)))

        #[
        var gasPrice: GasPrice = newRandomGasPrice()
        check(gasPrice.serialize().len == {
            uint8(GAS_PRICE_PREFIX)
        }.getLength(char(GAS_PRICE_PREFIX)))
        ]#

        for first in 0 ..< 5:
            var
                e1: Element
                holder: uint16 = uint16(rand(high(int16)))
            case first:
                of 0:
                    e1 = newRandomVerification(holder)
                of 1:
                    var hash: Hash[256] = Hash[256]()
                    for b in 0 ..< 32:
                        hash.data[b] = uint8(rand(255))

                    var mrvp: MeritRemovalVerificationPacket = newMeritRemovalVerificationPacketObj(hash)
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
                        var hash: Hash[256] = Hash[256]()
                        for b in 0 ..< 32:
                            hash.data[b] = uint8(rand(255))

                        var mrvp: MeritRemovalVerificationPacket = newMeritRemovalVerificationPacketObj(hash)
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
                        uint8(MERIT_REMOVAL_PREFIX)
                    }.getLength(char(MERIT_REMOVAL_PREFIX))
                    eLen: int
                dec(len)

                for _ in 0 ..< 2:
                    eLen = 0
                    if int(mr.serialize()[len]) == VERIFICATION_PACKET_PREFIX:
                        eLen = {
                            uint8(VERIFICATION_PACKET_PREFIX)
                        }.getLength(char(VERIFICATION_PACKET_PREFIX))

                    len += MERIT_REMOVAL_ELEMENT_SET.getLength(
                        mr.serialize()[len],
                        mr.serialize()[len + 1 .. len + eLen].fromBinary(),
                        MERIT_REMOVAL_PREFIX
                    ) + eLen

                check(mr.serialize().len == len)
