#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

type BlockHeader* = ref object
    #Version.
    version*: uint32
    #Hash of the last block.
    last*: RandomXHash
    #Merkle of the contents.
    contents*: Hash[256]

    #Amount of Merit required for a Transaction to be included.
    significant*: uint16
    #Salt used when hasing sketch elements in order to avoid collisions.
    sketchSalt*: string
    #Merkle of the included sketch hashes.
    sketchCheck*: Hash[256]

    #Miner.
    case newMiner*: bool
        of true:
            minerKey*: BLSPublicKey
        of false:
            minerNick*: uint16
    #Timestamp.
    time*: uint32
    #Proof.
    proof*: uint32
    #Signature.
    signature*: BLSSignature

    #Interim Block hash.
    interimHash*: string
    #Block hash.
    hash*: RandomXHash

#Constructors.
func newBlockHeaderObj*(
    version: uint32,
    last: RandomXHash,
    contents: Hash[256],
    significant: uint16,
    sketchSalt: string,
    sketchCheck: Hash[256],
    miner: BLSPublicKey,
    time: uint32,
    proof: uint32,
    signature: BLSSignature
): BlockHeader {.inline, forceCheck: [].} =
    BlockHeader(
        version: version,
        last: last,
        contents: contents,

        significant: significant,
        sketchSalt: sketchSalt,
        sketchCheck: sketchCheck,

        newMiner: true,
        minerKey: miner,
        time: time,
        proof: proof,
        signature: signature
    )

func newBlockHeaderObj*(
    version: uint32,
    last: RandomXHash,
    contents: Hash[256],
    significant: uint16,
    sketchSalt: string,
    sketchCheck: Hash[256],
    miner: uint16,
    time: uint32,
    proof: uint32,
    signature: BLSSignature
): BlockHeader {.inline, forceCheck: [].} =
    BlockHeader(
        version: version,
        last: last,
        contents: contents,

        significant: significant,
        sketchSalt: sketchSalt,
        sketchCheck: sketchCheck,

        newMiner: false,
        minerNick: miner,
        time: time,
        proof: proof,
        signature: signature
    )

#Sign and hash the header via a passed in serialization.
proc hash*(
    miner: MinerWallet,
    header: var BlockHeader,
    serialized: string,
    proof: uint32
) {.forceCheck: [].} =
    header.proof = proof
    header.interimHash = RandomX(serialized).toString()
    header.signature = miner.sign(header.interimHash)
    header.hash = RandomX(header.interimHash & header.signature.serialize())

#Hash the header via a passed in serialization.
proc hash*(
    header: var BlockHeader,
    serialized: string
) {.forceCheck: [].} =
    header.interimHash = RandomX(serialized).toString()
    header.hash = RandomX(header.interimHash & header.signature.serialize())
