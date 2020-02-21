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

#Elements lib.
import ../../Consensus/Elements/Elements

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

template SEND_DIFFICULTY_NONCE(
    holder: uint16
): string =
    holder.toBinary(NICKNAME_LEN) & "sn"

template HOLDER_DATA_DIFFICULTY(
    holder: uint16
): string =
    holder.toBinary(NICKNAME_LEN) & "d"

template DATA_DIFFICULTY_NONCE(
    holder: uint16
): string =
    holder.toBinary(NICKNAME_LEN) & "dn"

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

template MERIT_REMOVAL(
    mr: MeritRemoval
): string =
    mr.reason.toString() & "r"

template MERIT_REMOVAL_NONCES(
    holder: uint16
): string =
    holder.toBinary(NICKNAME_LEN) & "n"

#Put/Get/Del/Commit for the Consensus DB.
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

proc del(
    db: DB,
    key: string
) {.forceCheck: [].} =
    db.consensus.deleted.incl(key)
    db.consensus.cache.del(key)

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
    var unmentioned: string
    for hash in db.consensus.unmentioned:
        unmentioned &= hash.toString()
    items[^1] = (key: UNMENTIONED(), value: unmentioned)
    db.consensus.unmentioned = initHashSet[Hash[256]]()

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
    db.consensus.unmentioned.incl(unmentioned)

proc mention*(
    db: DB,
    mentioned: Hash[256]
) {.inline, forceCheck: [].} =
    db.consensus.unmentioned.excl(mentioned)

proc save*(
    db: DB,
    sendDiff: SendDifficulty
) {.forceCheck: [].} =
    db.put(HOLDER_NONCE(sendDiff.holder), sendDiff.nonce.toBinary())
    db.put(HOLDER_SEND_DIFFICULTY(sendDiff.holder), sendDiff.difficulty.toString())
    db.put(SEND_DIFFICULTY_NONCE(sendDiff.holder), sendDiff.nonce.toBinary())

    db.put(
        BLOCK_ELEMENT(sendDiff.holder, sendDiff.nonce),
        char(SEND_DIFFICULTY_PREFIX) & sendDiff.difficulty.toString()
    )

proc override*(
    db: DB,
    holder: uint16,
    nonce: int
) {.forceCheck: [].} =
    db.put(HOLDER_NONCE(holder), nonce.toBinary())

proc override*(
    db: DB,
    sendDiff: SendDifficulty
) {.forceCheck: [].} =
    db.put(HOLDER_SEND_DIFFICULTY(sendDiff.holder), sendDiff.difficulty.toString())
    db.put(SEND_DIFFICULTY_NONCE(sendDiff.holder), sendDiff.nonce.toBinary())

proc override*(
    db: DB,
    dataDiff: DataDifficulty
) {.forceCheck: [].} =
    db.put(HOLDER_DATA_DIFFICULTY(dataDiff.holder), dataDiff.difficulty.toString())
    db.put(DATA_DIFFICULTY_NONCE(dataDiff.holder), dataDiff.nonce.toBinary())

proc save*(
    db: DB,
    dataDiff: DataDifficulty
) {.forceCheck: [].} =
    db.put(HOLDER_NONCE(dataDiff.holder), dataDiff.nonce.toBinary())
    db.put(HOLDER_DATA_DIFFICULTY(dataDiff.holder), dataDiff.difficulty.toString())
    db.put(DATA_DIFFICULTY_NONCE(dataDiff.holder), dataDiff.nonce.toBinary())

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

proc saveMeritRemovalNonce*(
    db: DB,
    holder: uint16,
    nonce: int
) {.forceCheck: [].} =
    var existing: string
    try:
        existing = db.get(MERIT_REMOVAL_NONCES(holder))
    except DBReadError:
        discard

    db.put(MERIT_REMOVAL_NONCES(holder), existing & nonce.toBinary(INT_LEN))

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
): HashSet[Hash[256]] {.forceCheck: [].} =
    result = initHashSet[Hash[256]]()

    var unmentioned: string
    try:
        unmentioned = db.get(UNMENTIONED())
    except DBReadError:
        return

    for h in countup(0, unmentioned.len - 1, 32):
        try:
            result.incl(unmentioned[h ..< h + 32].toHash(256))
        except ValueError as e:
            panic("Couldn't parse an unmentioned hash: " & e.msg)
    db.consensus.unmentioned = result

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

proc loadSendDifficultyNonce*(
    db: DB,
    holder: uint16
): int {.forceCheck: [].} =
    try:
        result = db.get(SEND_DIFFICULTY_NONCE(holder)).fromBinary()
    except DBReadError:
        return -1

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

proc loadDataDifficultyNonce*(
    db: DB,
    holder: uint16
): int {.forceCheck: [].} =
    try:
        result = db.get(DATA_DIFFICULTY_NONCE(holder)).fromBinary()
    except DBReadError:
        return -1

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

proc loadMeritRemovalNonces*(
    db: DB,
    holder: uint16
): HashSet[int] {.forceCheck: [].} =
    result = initHashSet[int]()

    var nonces: string
    try:
        nonces = db.get(MERIT_REMOVAL_NONCES(holder))
    except DBReadError:
        return

    for n in countup(0, nonces.len - 1, INT_LEN):
        result.incl(nonces[n ..< n + INT_LEN].fromBinary())

#Delete a Transaction Status.
proc delete*(
    db: DB,
    hash: Hash[256]
) {.forceCheck: [].} =
    db.del(STATUS(hash))
    db.consensus.unmentioned.excl(hash)

#Delete a Block Element.
proc delete*(
    db: DB,
    holder: uint16,
    nonce: int
) {.forceCheck: [].} =
    db.del(BLOCK_ELEMENT(holder, nonce))
    db.del(SIGNATURE(holder, nonce))

#Delete a now-aggregated signature.
proc deleteSignature*(
    db: DB,
    holder: uint16,
    nonce: int
) {.inline, forceCheck: [].} =
    db.del(SIGNATURE(holder, nonce))

#Delete a holder's current Send Difficulty.
proc deleteSendDifficulty*(
    db: DB,
    holder: uint16
) {.forceCheck: [].} =
    db.del(HOLDER_SEND_DIFFICULTY(holder))
    db.del(SEND_DIFFICULTY_NONCE(holder))

#Delete a holder's current Data Difficulty.
proc deleteDataDifficulty*(
    db: DB,
    holder: uint16
) {.forceCheck: [].} =
    db.del(HOLDER_DATA_DIFFICULTY(holder))
    db.del(DATA_DIFFICULTY_NONCE(holder))

#Delete a malicious proof for a holder.
proc deleteMaliciousProof*(
    db: DB,
    mr: MeritRemoval
) {.forceCheck: [].} =
    var proofs: int
    try:
        #Get the proof count and updae it.
        proofs = db.get(HOLDER_MALICIOUS_PROOFS(mr.holder)).fromBinary()
        if proofs == 0:
            db.del(HOLDER_MALICIOUS_PROOFS(mr.holder))
        else:
            db.put(HOLDER_MALICIOUS_PROOFS(mr.holder), (proofs - 1).toBinary())
    except DBReadError as e:
        panic("Couldn't get the amount of malicious proofs a holder has when deleting one: " & e.msg)

    try:
        #Find the proof we're deleting.
        for p in 0 ..< proofs:
            try:
                if db.get(HOLDER_MALICIOUS_PROOF(mr.holder, p)).parseMeritRemoval().reason == mr.reason:
                    db.put(HOLDER_MALICIOUS_PROOF(mr.holder, p), db.get(HOLDER_MALICIOUS_PROOF(mr.holder, proofs)))
                    break
            except ValueError as e:
                panic("Couldn't parse a MeritRemoval we saved to the database as a malicious proof: " & e.msg)
    except DBReadError as e:
        panic("Couldn't load a malicious proof of a holder when deleting one: " & e.msg)

    #Delete the last proof.
    #If we haven't found the proof already, it is the last proof.
    #If we did find it, we moved the last proof to its place.
    db.del(HOLDER_MALICIOUS_PROOF(mr.holder, proofs))

#Deletes a MeritRemoval.
proc deleteMeritRemoval*(
    db: DB,
    mr: MeritRemoval
) {.forceCheck: [].} =
    #Delete the MeritRemoval.
    db.del(MERIT_REMOVAL(mr))

    #Delete its nonce.
    var nonce: int = -1
    case mr.element1:
        of Verification as _:
            discard
        of VerificationPacket as _:
            discard
        of SendDifficulty as sd:
            nonce = sd.nonce
        of DataDifficulty as dd:
            nonce = dd.nonce
        else:
            panic("Unknown Element included in the MeritRemoval being deleted.")

    if nonce != -1:
        var existing: string
        try:
            existing = db.get(MERIT_REMOVAL_NONCES(mr.holder))
        except DBReadError as e:
            panic("Couldn't get the nonces of a holder who has a MeritRemoval being deleted: " & e.msg)

        for n in countup(0, existing.len - 1, INT_LEN):
            if existing[n ..< n + INT_LEN].fromBinary() == nonce:
                existing = existing[0 ..< n] & existing[n + INT_LEN ..< existing.len]
                break

        db.put(MERIT_REMOVAL_NONCES(mr.holder), existing)

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

#Prune a Transaction.
proc prune*(
    db: DB,
    hash: Hash[256]
) {.forceCheck: [].} =
    db.del(TRANSACTION(hash))
    db.del(STATUS(hash))
    db.consensus.unmentioned.excl(hash)
