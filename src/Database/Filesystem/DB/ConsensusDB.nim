#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Transaction object.
import ../../Transactions/objects/TransactionObj

#Element objects.
import ../../Consensus/Elements/objects/VerificationObj
import ../../Consensus/Elements/objects/VerificationPacketObj
import ../../Consensus/Elements/objects/SendDifficultyObj
import ../../Consensus/Elements/objects/DataDifficultyObj
import ../../Consensus/Elements/MeritRemoval

#TransactionStatus object.
import ../../Consensus/objects/TransactionStatusObj

#Serialization libs.
import ../../../Network/Serialize/SerializeCommon

import Serialize/Transactions/DBSerializeTransaction
import Serialize/Transactions/ParseTransaction

import ../../../Network/Serialize/Consensus/SerializeMeritRemoval
import ../../../Network/Serialize/Consensus/ParseMeritRemoval

import Serialize/Consensus/SerializeTransactionStatus
import Serialize/Consensus/ParseTransactionStatus

#DB object.
import objects/DBObj
export DBObj

#Sets standard lib.
import sets

#Tables standard lib.
import tables

#Key generators.
template STATUS(
    hash: Hash[256]
): string =
    hash.toString()

template UNMENTIONED(): string =
    "u"

template HOLDER_NONCE(
    holder: uint16
): string =
    holder.toBinary(NICKNAME_LEN)

template HOLDER_ARCHIVED_NONCE(
    holder: uint16
): string =
    holder.toBinary(NICKNAME_LEN) & "a"

template HOLDER_SEND_DIFFICULTY(
    holder: uint16
): string =
    holder.toBinary(NICKNAME_LEN) & "s"

template HOLDER_DATA_DIFFICULTY(
    holder: uint16
): string =
    holder.toBinary(NICKNAME_LEN) & "d"

template BLOCK_ELEMENT(
    holder: uint16,
    nonce: int
): string =
    holder.toBinary(NICKNAME_LEN) & nonce.toBinary(INT_LEN)

template SIGNATURE(
    holder: uint16,
    nonce: int
): string =
    BLOCK_ELEMENT(holder, nonce) & "s"

template TRANSACTION(
    hash: Hash[256]
): string =
    hash.toString() & "t"

template MERIT_REMOVAL(
    mr: MeritRemoval
): string =
    var
        e1: Element = mr.element1
        e2: Element = mr.element2
    if e1 of MeritRemovalVerificationPacket:
        e1 = newVerificationObj(cast[MeritRemovalVerificationPacket](e1).hash)
    if e2 of MeritRemovalVerificationPacket:
        e2 = newVerificationObj(cast[MeritRemovalVerificationPacket](e2).hash)

    Blake256(
        newMeritRemoval(
            mr.holder,
            mr.partial,
            e1,
            e2,
            @[]
        ).serialize()
    ).toString() & "r"

template MALICIOUS_PROOFS(): string =
    "p"

template HOLDER_MALICIOUS_PROOFS(
    holder: uint16
): string =
    holder.toBinary(NICKNAME_LEN) & "p"

template HOLDER_MALICIOUS_PROOF(
    holder: uint16,
    nonce: int
): string =
    holder.toBinary(NICKNAME_LEN) & nonce.toBinary(INT_LEN) & "p"

#Put/Get/Commit for the Consensus DB.
proc put(
    db: DB,
    key: string,
    val: string
) {.forceCheck: [].} =
    db.consensus.cache[key] = val
    db.consensus.deleted.excl(key)

proc get(
    db: DB,
    key: string
): string {.forceCheck: [
    DBReadError
].} =
    if db.consensus.deleted.contains(key):
        raise newLoggedException(DBReadError, "Key deleted.")

    if db.consensus.cache.hasKey(key):
        try:
            return db.consensus.cache[key]
        except KeyError as e:
            panic("Couldn't get a key from a table confirmed to exist: " & e.msg)

    try:
        result = db.lmdb.get("consensus", key)
    except Exception as e:
        raise newLoggedException(DBReadError, e.msg)

proc commit*(
    db: DB
) {.forceCheck: [].} =
    for key in db.consensus.deleted:
        try:
            db.lmdb.delete("consensus", key)
        except Exception:
            #If we delete something before it's committed, it'll throw.
            discard
    db.consensus.deleted = initHashSet[string]()

    var items: seq[tuple[key: string, value: string]] = newSeq[tuple[key: string, value: string]](db.consensus.cache.len + 1)
    try:
        var i: int = 0
        for key in db.consensus.cache.keys():
            items[i] = (key: key, value: db.consensus.cache[key])
            inc(i)
    except KeyError as e:
        panic("Couldn't get a value from the table despiting getting the key from .keys(): " & e.msg)

    #Save the unmentioned hashes.
    items[^1] = (key: UNMENTIONED(), value: db.consensus.unmentioned)
    db.consensus.unmentioned = ""

    try:
        db.lmdb.put("consensus", items)
    except Exception as e:
        panic("Couldn't save data to the Database: " & e.msg)

    db.consensus.cache = initTable[string, string]()

#Save functions.
proc save*(
    db: DB,
    hash: Hash[256],
    status: TransactionStatus
) {.inline, forceCheck: [].} =
    db.put(STATUS(hash), status.serialize())

proc addUnmentioned*(
    db: DB,
    unmentioned: Hash[256]
) {.inline, forceCheck: [].} =
    db.consensus.unmentioned &= unmentioned.toString()

proc save*(
    db: DB,
    sendDiff: SendDifficulty
) {.forceCheck: [].} =
    db.put(HOLDER_NONCE(sendDiff.holder), sendDiff.nonce.toBinary())
    db.put(HOLDER_SEND_DIFFICULTY(sendDiff.holder), sendDiff.difficulty.toString())

    db.put(
        BLOCK_ELEMENT(sendDiff.holder, sendDiff.nonce),
        char(SEND_DIFFICULTY_PREFIX) & sendDiff.difficulty.toString()
    )

proc save*(
    db: DB,
    dataDiff: DataDifficulty
) {.forceCheck: [].} =
    db.put(HOLDER_NONCE(dataDiff.holder), dataDiff.nonce.toBinary())
    db.put(HOLDER_DATA_DIFFICULTY(dataDiff.holder), dataDiff.difficulty.toString())

    db.put(
        BLOCK_ELEMENT(dataDiff.holder, dataDiff.nonce),
        char(DATA_DIFFICULTY_PREFIX) & dataDiff.difficulty.toString()
    )

proc saveSignature*(
    db: DB,
    holder: uint16,
    nonce: int,
    signature: BLSSignature
) {.inline, forceCheck: [].} =
    db.put(SIGNATURE(holder, nonce), signature.serialize())

proc saveArchived*(
    db: DB,
    holder: uint16,
    nonce: int
) {.inline, forceCheck: [].} =
    db.put(HOLDER_ARCHIVED_NONCE(holder), nonce.toBinary())

proc saveTransaction*(
    db: DB,
    tx: Transaction
) {.inline, forceCheck: [].} =
    db.put(TRANSACTION(tx.hash), tx.serialize())

proc saveMaliciousProof*(
    db: DB,
    mr: SignedMeritRemoval
) {.forceCheck: [].} =
    var nonce: int = 0
    try:
        nonce = db.get(HOLDER_MALICIOUS_PROOFS(mr.holder)).fromBinary() + 1
    except DBReadError:
        discard
    db.put(HOLDER_MALICIOUS_PROOF(mr.holder, nonce), mr.signedSerialize())
    db.put(HOLDER_MALICIOUS_PROOFS(mr.holder), nonce.toBinary())

    if not db.consensus.malicious.contains(mr.holder):
        var malicious: string = ""
        try:
            malicious = db.get(MALICIOUS_PROOFS())
        except DBReadError:
            discard
        db.put(MALICIOUS_PROOFS(), malicious & mr.holder.toBinary(NICKNAME_LEN))

proc save*(
    db: DB,
    mr: MeritRemoval
) {.inline, forceCheck: [].} =
    db.put(MERIT_REMOVAL(mr), "")

#Load functions.
proc load*(
    db: DB,
    hash: Hash[256]
): TransactionStatus {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(STATUS(hash)).parseTransactionStatus(hash)
    except DBReadError as e:
        raise e

proc loadUnmentioned*(
    db: DB
): seq[Hash[256]] {.forceCheck: [].} =
    var unmentioned: string
    try:
        unmentioned = db.get(UNMENTIONED())
    except DBReadError:
        return @[]

    result = newSeq[Hash[256]](unmentioned.len div 32)
    for i in countup(0, unmentioned.len - 1, 32):
        try:
            result[i div 32] = unmentioned[i ..< i + 32].toHash(256)
        except ValueError as e:
            panic("Couldn't parse an unmentioned hash: " & e.msg)

proc load*(
    db: DB,
    holder: uint16
): int {.forceCheck: [].} =
    try:
        result = db.get(HOLDER_NONCE(holder)).fromBinary()
    except DBReadError:
        result = -1

proc loadSendDifficulty*(
    db: DB,
    holder: uint16
): Hash[256] {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(HOLDER_SEND_DIFFICULTY(holder)).toHash(256)
    except ValueError:
        panic("Couldn't turn a 32-byte value into a 32-byte hash.")
    except DBReadError as e:
        raise e

proc loadDataDifficulty*(
    db: DB,
    holder: uint16
): Hash[256] {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(HOLDER_DATA_DIFFICULTY(holder)).toHash(256)
    except ValueError:
        panic("Couldn't turn a 32-byte value into a 32-byte hash.")
    except DBReadError as e:
        raise e

proc load*(
    db: DB,
    holder: uint16,
    nonce: int
): BlockElement {.forceCheck: [
    DBReadError
].} =
    var elem: string
    try:
        elem = db.get(BLOCK_ELEMENT(holder, nonce))
    except DBReadError as e:
        fcRaise e

    try:
        case int(elem[0]):
            of SEND_DIFFICULTY_PREFIX:
                result = newSendDifficultyObj(nonce, elem[1 ..< 33].toHash(256))
                result.holder = holder
            of DATA_DIFFICULTY_PREFIX:
                result = newDataDifficultyObj(nonce, elem[1 ..< 33].toHash(256))
                result.holder = holder
            else:
                panic("Tried to load an unknown Block Element: " & $int(elem[0]))
    except ValueError:
        panic("Couldn't convert a 32-byte value to a 32-byte hash.")

proc loadSignature*(
    db: DB,
    holder: uint16,
    nonce: int
): BLSSignature {.forceCheck: [
    DBReadError
].} =
    try:
        result = newBLSSignature(db.get(SIGNATURE(holder, nonce)))
    except BLSError as e:
        panic("Saved an invalid BLS signature to the Database: " & e.msg)
    except DBReadError as e:
        raise e

proc loadArchived*(
    db: DB,
    holder: uint16
): int {.forceCheck: [].} =
    try:
        result = db.get(HOLDER_ARCHIVED_NONCE(holder)).fromBinary()
    except DBReadError:
        result = -1

proc loadTransaction*(
    db: DB,
    hash: Hash[256]
): Transaction {.forceCheck: [
    DBReadError
].} =
    try:
        result = hash.parseTransaction(db.get(TRANSACTION(hash)))
    except ValueError as e:
        panic("Couldn't parse a Transaction saved to the Consensus DB: " & e.msg)
    except DBReadError as e:
        raise e

#Load the malicious proofs table.
proc loadMaliciousProofs*(
    db: DB
): Table[uint16, seq[SignedMeritRemoval]] {.forceCheck: [].} =
    result = initTable[uint16, seq[SignedMeritRemoval]]()

    var malicious: string = ""
    try:
        malicious = db.get(MALICIOUS_PROOFS())
    except DBReadError:
        discard

    for h in countup(0, malicious.len - 1, 2):
        var holder: uint16 = uint16(malicious[h ..< h + 2].fromBinary())
        db.consensus.malicious.incl(holder)
        result[holder] = @[]

        try:
            for p in 0 .. db.get(HOLDER_MALICIOUS_PROOFS(holder)).fromBinary():
                try:
                    result[holder].add(db.get(HOLDER_MALICIOUS_PROOF(holder, p)).parseSignedMeritRemoval())
                except ValueError as e:
                    panic("Couldn't parse a MeritRemoval we saved to the database as a malicious proof: " & e.msg)
        except DBReadError:
            result.del(holder)

#Delete a now-aggregated signature.
proc deleteSignature*(
    db: DB,
    holder: uint16,
    nonce: int
) {.inline, forceCheck: [].} =
    db.consensus.deleted.incl(SIGNATURE(holder, nonce))

#Delete malicious proofs for a holder.
proc deleteMaliciousProofs*(
    db: DB,
    holder: uint16
) {.forceCheck: [].} =
    try:
        var proofs: int = db.get(HOLDER_MALICIOUS_PROOFS(holder)).fromBinary()
        db.consensus.deleted.incl(HOLDER_MALICIOUS_PROOFS(holder))
        for p in 0 .. proofs:
            db.consensus.deleted.incl(HOLDER_MALICIOUS_PROOF(holder, p))
    except DBReadError:
        discard

#Check if a MeritRemoval exists.
proc hasMeritRemoval*(
    db: DB,
    removal: MeritRemoval
): bool {.forceCheck: [].} =
    try:
        discard db.get(MERIT_REMOVAL(removal))
        result = true
    except DBReadError:
        result = false
