import random
import sets, tables

import ../../../../../../src/lib/[Util, Hash]
import ../../../../../../src/Wallet/MinerWallet

import ../../../../../../src/Database/Consensus/Elements/VerificationPacket
import ../../../../../../src/Database/Consensus/TransactionStatus

import ../../../../../../src/Database/Filesystem/DB/Serialize/Consensus/[
  SerializeTransactionStatus,
  ParseTransactionStatus
]

import ../../../../../Fuzzed
import ../../../../Consensus/CompareConsensus

suite "SerializeTransactionStatus":
  setup:
    #Create a TransactionStatus.
    var
      hash: Hash[256] = newRandomHash()
      status: TransactionStatus
      pendingSigs: seq[BLSSignature]

    status = newTransactionStatusObj(hash, rand(high(int32)))
    status.competing = rand(1) == 0
    status.verified = rand(1) == 0
    status.beaten = rand(1) == 0

    status.holders = initHashSet[uint16]()
    for h in 0 ..< rand(500):
      var holder: uint16 = uint16(rand(65535))
      status.holders.incl(holder)
      if rand(2) == 0:
        status.signatures[holder] = newMinerWallet().sign("")

    for holder in status.holders:
      if status.signatures.hasKey(holder):
        status.pending.incl(holder)
        status.packet.holders.add(holder)
        pendingSigs.add(status.signatures[holder])
        status.packet.signature = pendingSigs.aggregate()

  noFuzzTest "Serialize and parse an empty TransactionStatus.":
    status.competing = false
    status.verified = false
    status.beaten = false

    status.holders = initHashSet[uint16]()
    status.pending = initHashSet[uint16]()

    status.packet = newSignedVerificationPacketObj(status.packet.hash)
    status.signatures = initTable[uint16, BLSSignature]()

    compare(status, status.serialize().parseTransactionStatus(hash))

  highFuzzTest "Serialize and parse an unfinalized TransactionStatus.":
    compare(status, status.serialize().parseTransactionStatus(hash))

  highFuzzTest "Serialize and parse a finalized TransactionStatus.":
    status.pending = initHashSet[uint16]()
    status.packet = newSignedVerificationPacketObj(status.packet.hash)
    status.signatures = initTable[uint16, BLSSignature]()
    status.merit = rand(65535)
    compare(status, status.serialize().parseTransactionStatus(hash))
