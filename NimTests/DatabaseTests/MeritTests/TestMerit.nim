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

#Create a contents Merkle.
proc newContents(
    transactions: seq[Hash[384]] = @[],
    elements: seq[BlockElement] = @[],
): Hash[384] =
    var contents: Merkle = newMerkle(transactions)
    for elem in elements:
        contents.add(Blake384(elem.serializeContents()))
    result = contents.hash

#Create a verifiers Merkle.
proc newVerifiers(
    packets: seq[VerificationPacket]
): Hash[384] =
    var verifiers: Merkle = newMerkle()
    for packet in packets:
        verifiers.add(Blake384(packet.serialize()))
    result = verifiers.hash

#Create a Block, with every setting optional.
proc newBlankBlock*(
    version: uint32 = 0,
    last: ArgonHash = ArgonHash(),
    miner: MinerWallet = newMinerWallet(),
    significant: int = 0,
    sketchSalt: string = "",
    transactions: seq[Hash[384]] = @[],
    packets: seq[VerificationPacket] = @[],
    elements: seq[BlockElement] = @[],
    aggregate: BLSSignature = nil,
    time: uint32 = getTime(),
    proof: uint32 = 0
): Block =
    result = newBlockObj(
        version,
        last,
        newContents(transactions, elements),
        newVerifiers(packets),
        miner.publicKey,
        significant,
        sketchSalt,
        transactions,
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
    nick: uint16,
    miner: MinerWallet = newMinerWallet(),
    significant: int = 0,
    sketchSalt: string = "",
    transactions: seq[Hash[384]] = @[],
    packets: seq[VerificationPacket] = @[],
    elements: seq[BlockElement] = @[],
    aggregate: BLSSignature = nil,
    time: uint32 = getTime(),
    proof: uint32 = 0
): Block =
    result = newBlockObj(
        version,
        last,
        newContents(transactions, elements),
        newVerifiers(packets),
        nick,
        significant,
        sketchSalt,
        transactions,
        packets,
        elements,
        aggregate,
        time
    )
    miner.hash(result.header, proof)
