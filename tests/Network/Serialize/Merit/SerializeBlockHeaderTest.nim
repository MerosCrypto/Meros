import random

import ../../../../src/lib/[Util, Hash]
import ../../../../src/Wallet/MinerWallet

import ../../../../src/Database/Merit/BlockHeader

import ../../../../src/Network/Serialize/Merit/[
  SerializeBlockHeader,
  ParseBlockHeader
]

import ../../../Fuzzed
import ../../../Database/Merit/TestMerit
import ../../../Database/Merit/CompareMerit

#Whether or not to create a BlockHeader with a new miner.
var newMiner: bool = true

suite "SerializeBlockHeader":
  midFuzzTest "Serialize and parse.":
    var
      last: Hash[256] = newRandomHash()
      contents: Hash[256] = newRandomHash()
      sketchCheck: Hash[256] = newRandomHash()
      miner: MinerWallet
      header: BlockHeader
      reloaded: BlockHeader

    #Create the BlockHeaader.
    if newMiner:
      #Get a new miner.
      miner = newMinerWallet()

      header = newBlockHeader(
        uint32(rand(high(int32))),
        last,
        contents,
        uint32(rand(high(int32))),
        char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
        sketchCheck,
        miner.publicKey,
        uint32(rand(high(int32)))
      )
    else:
      header = newBlockHeader(
        uint32(rand(high(int32))),
        last,
        contents,
        uint32(rand(high(int32))),
        char(rand(255)) & char(rand(255)) & char(rand(255)) & char(rand(255)),
        sketchCheck,
        uint16(rand(high(int16))),
        uint32(rand(high(int32)))
      )
    getRandomX().hash(miner, header, uint16(rand(high(int16))))

    reloaded = header.serialize().parseBlockHeader(header.interimHash, header.hash)
    compare(header, reloaded)
    check header.serialize() == reloaded.serialize()

    newMiner = not newMiner
