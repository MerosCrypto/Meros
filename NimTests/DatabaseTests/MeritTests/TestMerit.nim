#Merit Testing Functions.

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Element lib.
import ../../../src/Database/Consensus/Elements/Element

#Block lib.
import ../../../src/Database/Merit/Block

#Test Database lib.
import ../TestDatabase
export TestDatabase

#Create a Block, with every setting optional.
proc newBlankBlock*(
    version: uint32 = 0,
    last: ArgonHash = ArgonHash(),
    contents: Hash[384] = Hash[384](),
    verifiers: Hash[384] = Hash[384](),
    miner: MinerWallet = newMinerWallet(),
    transactions: seq[Hash[384]] = @[],
    elements: seq[BlockElement] = @[],
    aggregate: BLSSignature = nil,
    time: uint32 = getTime(),
    proof: uint32 = 0
): Block =
    result = newBlockObj(
        version,
        last,
        contents,
        verifiers,
        miner.publicKey,
        transactions,
        elements,
        aggregate,
        time
    )
    miner.hash(result.header, proof)

#Create a Block with a nicname.
proc newBlankBlock*(
    version: uint32 = 0,
    last: ArgonHash = ArgonHash(),
    contents: Hash[384] = Hash[384](),
    verifiers: Hash[384] = Hash[384](),
    nick: uint32,
    miner: MinerWallet = newMinerWallet(),
    transactions: seq[Hash[384]] = @[],
    elements: seq[BlockElement] = @[],
    aggregate: BLSSignature = nil,
    time: uint32 = getTime(),
    proof: uint32 = 0
): Block =
    result = newBlockObj(
        version,
        last,
        contents,
        verifiers,
        nick,
        transactions,
        elements,
        aggregate,
        time
    )
    miner.hash(result.header, proof)
