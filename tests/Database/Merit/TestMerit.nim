#Merit Testing Functions.

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Element libs.
import ../../../src/Database/Consensus/Elements/Elements

#BlockHeader and Block libs.
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
    hashArg: Hash[256] = Hash[256]()
): VerificationPacket =
    var hash: Hash[256] = hashArg
    if hash == Hash[256]():
        for b in 0 ..< 32:
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

#Create a Block, with every setting optional.
var lastTime {.threadvar.}: uint32
proc newBlankBlock*(
    version: uint32 = 0,
    last: RandomXHash = RandomXHash(),
    significant: uint16 = 1,
    sketchSalt: string = newString(4),
    miner: MinerWallet = newMinerWallet(),
    packets: seq[VerificationPacket] = @[],
    elements: seq[BlockElement] = @[],
    aggregate: BLSSignature = newBLSSignature(),
    time: uint32 = getTime(),
    proof: uint32 = 0
): Block =
    var contents: tuple[packets: Hash[256], contents: Hash[256]] = newContents(packets, elements)
    result = newBlockObj(
        version,
        last,
        contents.contents,
        significant,
        sketchSalt,
        newSketchCheck(sketchSalt, packets),
        miner.publicKey,
        contents.packets,
        packets,
        elements,
        aggregate,
        time
    )
    miner.hash(result.header, proof)

#Create a Block with a nicname.
proc newBlankBlock*(
    version: uint32 = 0,
    last: RandomXHash = RandomXHash(),
    significant: uint16 = 1,
    sketchSalt: string = newString(4),
    nick: uint16,
    miner: MinerWallet = newMinerWallet(),
    packets: seq[VerificationPacket] = @[],
    elements: seq[BlockElement] = @[],
    aggregate: BLSSignature = newBLSSignature(),
    time: uint32 = getTime(),
    proof: uint32 = 0
): Block =
    var contents: tuple[packets: Hash[256], contents: Hash[256]] = newContents(packets, elements)
    result = newBlockObj(
        version,
        last,
        contents.contents,
        significant,
        sketchSalt,
        newSketchCheck(sketchSalt, packets),
        nick,
        contents.packets,
        packets,
        elements,
        aggregate,
        time
    )
    miner.hash(result.header, proof)
