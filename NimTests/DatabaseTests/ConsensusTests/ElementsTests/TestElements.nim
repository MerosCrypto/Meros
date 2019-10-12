#Elements Testing Functions.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Element lib.
import ../../../../src/Database/Consensus/Elements/Element
export Element

#Random standard lib.
import random

proc newRandomVerification*(
    holder: uint16 = uint16(rand(high(int16)))
): SignedVerification =
    var
        #Hash.
        hash: Hash[384]
        #Miner.
        miner: MinerWallet = newMinerWallet()

    #Randomize the hash.
    for b in 0 ..< 48:
        hash.data[b] = uint8(rand(255))

    #Randomize the miner's nick name.
    miner.nick = holder

    #Create the SignedVerification.
    result = newSignedVerificationObj(hash)
    #Sign it.
    miner.sign(result)

proc newRandomVerificationPacket*(
    holder: uint16 = uint16(rand(high(int16))),
    hash: Hash[384] = Hash[384]()
): SignedVerificationPacket =
    var
        #Hash.
        hashVal: Hash[384]
        #Miner.
        miner: MinerWallet = newMinerWallet()

    if hash == Hash[384]():
        #Randomize the hash.
        for b in 0 ..< 48:
            hashVal.data[b] = uint8(rand(255))
    else:
        hashVal = hash
    result = newSignedVerificationPacketObj(hashVal)

    #Randomize the participating holders.
    for h in 0 ..< rand(50) + 1:
        if h == 0:
            result.holders.add(holder)
        else:
            result.holders.add(uint16(rand(high(int16))))

    #Set a random signature.
    result.signature = miner.sign("")

proc newRandomMeritRemoval*(
    holder: uint16 = uint16(rand(high(int16)))
): SignedMeritRemoval

proc newRandomElement*(
    holder: uint16 = uint16(rand(high(int16))),
    verification: bool = true,
    packet: bool = true,
    sendDifficulty: bool = true,
    dataDifficulty: bool = true,
    gasPrice: bool = true,
    removal: bool = true
): Element =
    var
        possibilities: set[int8] = {}
        r: int8 = int8(rand(5))

    #Include all possibilities in the set.
    if verification: possibilities.incl(0)
    if packet: possibilities.incl(1)
    #[
    if sendDifficulty: possibilities.incl(2)
    if dataDifficulty: possibilities.incl(3)
    if gasPrice: possibilities.incl(4)
    ]#
    if removal: possibilities.incl(5)

    #While r is not a possibility, randomize it.
    while not (r in possibilities):
        r = int8(rand(5))

    case r:
        of 0:
            result = newRandomVerification(
                holder = holder
            )
        of 1:
            result = newRandomVerificationPacket(
                holder = holder
            )
        of 2:
            discard
        of 3:
            discard
        of 4:
            discard
        of 5:
            result = newRandomMeritRemoval()
        else:
            assert(false, "TestElements generated a number in possibilities that is not a valid case.")

proc newRandomMeritRemoval*(
    holder: uint16 = uint16(rand(high(int16)))
): SignedMeritRemoval =
    var
        partial: bool = rand(1) == 1
        e1: Element = newRandomElement(
            holder = holder,
            removal = false
        )
        e2: Element = newRandomElement(
            holder = holder,
            removal = false
        )
        signatures: seq[BLSSignature] = @[]
        lookup: seq[BLSPublicKey] = newSeq[BLSPublicKey](65536)

    if e1 of VerificationPacket:
        for holder in cast[VerificationPacket](e1).holders:
            lookup[int(holder)] = newMinerWallet().publicKey
    if e2 of VerificationPacket:
        for holder in cast[VerificationPacket](e2).holders:
            lookup[int(holder)] = newMinerWallet().publicKey

    if not partial:
        case e1:
            of Verification as verif:
                signatures.add(cast[SignedVerification](verif).signature)
            of VerificationPacket as vp:
                signatures.add(cast[SignedVerificationPacket](vp).signature)
            #[
            of SendDifficulty as sd:
                signatures.add(cast[SignedSendDifficulty](sd).signature)
            of DataDifficulty as dd:
                signatures.add(cast[SignedDataDifficulty](dd).signature)
            of GasPrice as gp:
                signatures.add(cast[SignedGasPrice](gp).signature)
            ]#
            else:
                assert(false, "newRandomElement generated a MeritRemoval despite being told not to.")

    case e2:
        of Verification as verif:
            signatures.add(cast[SignedVerification](verif).signature)
        of VerificationPacket as vp:
            signatures.add(cast[SignedVerificationPacket](vp).signature)
        #[
        of SendDifficulty as sd:
            signatures.add(cast[SignedSendDifficulty](sd).signature)
        of DataDifficulty as dd:
            signatures.add(cast[SignedDataDifficulty](dd).signature)
        of GasPrice as gp:
            signatures.add(cast[SignedGasPrice](gp).signature)
        ]#
        else:
            assert(false, "newRandomElement generated a MeritRemoval despite being told not to.")

    result = newSignedMeritRemoval(
        holder,
        partial,
        e1,
        e2,
        signatures.aggregate(),
        lookup
    )

proc newRandomBlockElement*(
    sendDifficulty: bool = true,
    dataDifficulty: bool = true,
    gasPrice: bool = true,
    removal: bool = true
): BlockElement =
    var
        possibilities: set[int8] = {}
        r: int8 = int8(rand(3))

    #Include all possibilities in the set.
    #[
    if sendDifficulty: possibilities.incl(0)
    if dataDifficulty: possibilities.incl(1)
    if gasPrice: possibilities.incl(2)
    ]#
    if removal: possibilities.incl(3)

    #While r is not a possibility, randomize it.
    while not (r in possibilities):
        r = int8(rand(3))

    case r:
        #Send Difficulty.
        of 0:
            discard

        #Data Difficulty.
        of 1:
            discard

        #Gas Price.
        of 2:
            discard

        #Merit Removal
        of 3:
            result = newRandomMeritRemoval()
        else:
            assert(false, "TestElements generated a number in possibilities that is not a valid case.")
