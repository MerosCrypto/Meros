#Merit Testing Functions.

#Util lib.
import ../../../src/lib/Util

#Hash and Merkle libs.
import ../../../src/lib/Hash
import ../../../src/lib/Merkle

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Element lib.
import ../../../src/Database/Consensus/Elements/Element

#Element Serialization libs.
import ../../../src/Network/Serialize/Consensus/SerializeVerification
import ../../../src/Network/Serialize/Consensus/SerializeVerificationPacket
import ../../../src/Network/Serialize/Consensus/SerializeMeritRemoval

#Block lib.
import ../../../src/Database/Merit/Block

#Test Database lib.
import ../TestDatabase
export TestDatabase

#Random standard lib.
import random

#Create a valid VerificationPacket.
proc newValidVerificationPacket*(
    holders: seq[BLSPublicKey],
    exclude: seq[uint16] = @[],
    hashArg: Hash[384] = Hash[384]()
): VerificationPacket =
    var hash: Hash[384] = hashArg
    if hash == Hash[384]():
        for b in 0 ..< 48:
            hash.data[b] = uint8(rand(255))

    result = newVerificationPacketObj(hash)
    for h in 0 ..< holders.len:
        var found: bool = false
        for e in exclude:
            if uint16(h) == e:
                found = true
                break
        if found:
            continue

        if rand(1) == 0:
            result.holders.add(uint16(h))

    #Make sure there's at least one holder.
    while result.holders.len == 0:
        var
            h: uint16 = uint16(rand(high(holders)))
            found: bool = false
        for e in exclude:
            if h == e:
                found = true
                break
        if found:
            continue

        result.holders.add(uint16(h))

#Create a contents Merkle.
proc newContents(
    packets: seq[VerificationPacket] = @[],
    elements: seq[BlockElement] = @[],
): Hash[384] =
    var contents: Merkle = newMerkle()
    for packet in packets:
        contents.add(Blake384(packet.serializeContents()))
    for elem in elements:
        contents.add(Blake384(elem.serializeContents()))
    result = contents.hash

#Create a Block, with every setting optional.
proc newBlankBlock*(
    version: uint32 = 0,
    last: ArgonHash = ArgonHash(),
    significant: uint16 = 0,
    sketchSalt: string = "\0\0\0\0",
    miner: MinerWallet = newMinerWallet(),
    packets: seq[VerificationPacket] = @[],
    elements: seq[BlockElement] = @[],
    aggregate: BLSSignature = nil,
    time: uint32 = getTime(),
    proof: uint32 = 0
): Block =
    result = newBlockObj(
        version,
        last,
        newContents(packets, elements),
        significant,
        sketchSalt,
        miner.publicKey,
        packets,
        elements,
        aggregate,
        time
    )
    miner.hash(result.header, proof)

#Create a Block with a nicname.
proc newBlankBlock*(
    version: uint32 = 0,
    last: ArgonHash = ArgonHash(),
    significant: uint16 = 0,
    sketchSalt: string = "\0\0\0\0",
    nick: uint16,
    miner: MinerWallet = newMinerWallet(),
    packets: seq[VerificationPacket] = @[],
    elements: seq[BlockElement] = @[],
    aggregate: BLSSignature = nil,
    time: uint32 = getTime(),
    proof: uint32 = 0
): Block =
    result = newBlockObj(
        version,
        last,
        newContents(packets, elements),
        significant,
        sketchSalt,
        nick,
        packets,
        elements,
        aggregate,
        time
    )
    miner.hash(result.header, proof)
