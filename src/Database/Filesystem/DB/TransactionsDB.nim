#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet libs.
import ../../../Wallet/MinerWallet
import ../../../Wallet/Wallet

#Transaction and Mint object.
import ../../Transactions/objects/TransactionObj
import ../../Transactions/objects/MintObj

#Serialization libs.
import Serialize/Transactions/SerializeMintOutput
import Serialize/Transactions/SerializeSendOutput
import Serialize/Transactions/DBSerializeTransaction

import Serialize/Transactions/ParseMintOutput
import Serialize/Transactions/ParseSendOutput
import Serialize/Transactions/ParseTransaction

#DB object.
import objects/DBObj
export DBObj

#Tables standard lib.
import tables

#Put/Get/Delete/Commit for the Transactions DB.
proc put(
    db: DB,
    key: string,
    val: string
) {.forceCheck: [].} =
    db.transactions.cache[key] = val

proc get(
    db: DB,
    key: string
): string {.forceCheck: [
    DBReadError
].} =
    if db.transactions.cache.hasKey(key):
        try:
            return db.transactions.cache[key]
        except KeyError as e:
            doAssert(false, "Couldn't get a key from a table confirmed to exist: " & e.msg)

    try:
        result = db.lmdb.get("transactions", key)
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc delete(
    db: DB,
    key: string
) {.forceCheck: [].} =
    db.transactions.cache.del(key)
    db.transactions.deleted.add(key)

proc commit*(
    db: DB
) {.forceCheck: [].} =
    for key in db.transactions.deleted:
        try:
            db.lmdb.delete("transactions", key)
        except Exception:
            #If we delete something before it's committed, it'll throw.
            discard
    db.transactions.deleted = @[]

    var items: seq[tuple[key: string, value: string]] = newSeq[tuple[key: string, value: string]](db.transactions.cache.len)
    try:
        var i: int = 0
        for key in db.transactions.cache.keys():
            items[i] = (key: key, value: db.transactions.cache[key])
            inc(i)
    except KeyError as e:
        doAssert(false, "Couldn't get a value from the table despiting getting the key from .keys(): " & e.msg)

    try:
        db.lmdb.put("transactions", items)
    except Exception as e:
        doAssert(false, "Couldn't save data to the Database: " & e.msg)

    db.transactions.cache = initTable[string, string]()

#Save functions.
proc save*(
    db: DB,
    tx: Transaction
) {.forceCheck: [].} =
    db.put(tx.hash.toString(), tx.serialize())

proc saveVerified*(
    db: DB,
    hash: Hash[384]
) {.forceCheck: [].} =
    db.put(hash.toString() & "vrf", "")

proc save*(
    db: DB,
    key: BLSPublicKey,
    height: int
) {.forceCheck: [].} =
    db.put(key.toString() & "mh", height.toBinary())

proc saveMintNonce*(
    db: DB,
    nonce: uint32
) {.forceCheck: [].} =
    db.put("mint", nonce.toBinary())

proc save*(
    db: DB,
    hash: Hash[384],
    utxo: MintOutput
) {.forceCheck: [].} =
    db.put(hash.toString() & char(0), utxo.serialize())

proc save*(
    db: DB,
    hashArg: Hash[384],
    utxos: seq[SendOutput]
) {.forceCheck: [].} =
    var
        hash: string = hashArg.toString()
        spendable: string
    for i in 0 ..< utxos.len:
        db.put(hash & char(i), utxos[i].serialize())
        try:
            spendable = db.get(utxos[i].key.toString())
        except DBReadError:
            spendable = ""

        db.put(utxos[i].key.toString(), spendable & hash & char(i))

proc saveData*(
    db: DB,
    sender: EdPublicKey,
    hash: Hash[384]
) {.forceCheck: [
    DBReadError
].} =
    try:
        var hash: Hash[384] = db.get(sender.toString() & "d").toHash(384)
        db.delete(hash.toString() & "s")
    except DBReadError:
        discard
    except ValueError as e:
        raise newException(DBReadError, e.msg)

    db.put(sender.toString() & "d", hash.toString())
    db.put(hash.toString() & "s", sender.toString())

#Delete functions.
proc deleteUTXO*(
    db: DB,
    hash: Hash[384]
) {.forceCheck: [].} =
    db.delete(hash.toString() & char(0))

proc deleteUTXO*(
    db: DB,
    hash: Hash[384],
    nonce: int
) {.forceCheck: [
    DBReadError
].} =
    var
        utxoLoc: string = hash.toString() & char(nonce)
        utxoStr: string
    try:
        utxoStr = db.get(utxoLoc)
    except DBReadError as e:
        fcRaise e
    db.delete(utxoLoc)

    var
        utxo: SendOutput
        spendable: string
    try:
        utxo = utxoStr.parseSendOutput()
        spendable = db.get(utxo.key.toString())
    except Exception as e:
        raise newException(DBReadError, e.msg)

    for i in countup(0, spendable.len - 1, 49):
        if spendable[i ..< i + 49] == utxoLoc:
            spendable = spendable.substr(0, i - 1) & spendable.substr(i + 49)
            break

    db.put(utxo.key.toString(), spendable)

#Load functions.
proc load*(
    db: DB,
    hashArg: Hash[384]
): Transaction {.forceCheck: [
    DBReadError
].} =
    var hash: string = hashArg.toString()
    try:
        result = db.get(hash).parseTransaction()

        if not (result of Mint):
            result.verified = true
            try:
                discard db.get(hash & "vrf")
            except DBReadError:
                result.verified = false

    except Exception as e:
        raise newException(DBReadError, e.msg)

proc load*(
    db: DB,
    key: BLSPublicKey
): int {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(key.toString() & "mh").fromBinary()
    except DBReadError as e:
        fcRaise e

proc loadMintNonce*(
    db: DB
): uint32 {.forceCheck: [
    DBReadError
].} =
    try:
        result = uint32(db.get("mint").fromBinary())
    except DBReadError as e:
        fcRaise e

proc loadMintUTXO*(
    db: DB,
    hash: Hash[384]
): MintOutput {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(hash.toString() & char(0)).parseMintOutput()
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadSendUTXO*(
    db: DB,
    hash: Hash[384],
    nonce: int
): SendOutput {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(hash.toString() & char(nonce)).parseSendOutput()
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadSender*(
    db: DB,
    hash: Hash[384]
): EdPublicKey {.forceCheck: [
    DBReadError
].} =
    try:
        result = newEdPublicKey(db.get(hash.toString() & "s"))
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadData*(
    db: DB,
    key: EdPublicKey
): Hash[384] {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(key.toString() & "d").toHash(384)
    except DBReadError as e:
        fcRaise e
    except ValueError as e:
        raise newException(DBReadError, e.msg)

proc loadSpendable*(
    db: DB,
    key: EdPublicKey
): seq[SendInput] {.forceCheck: [
    DBReadError
].} =
    var spendable: string
    try:
        spendable = db.get(key.toString())
    except Exception as e:
        raise newException(DBReadError, e.msg)

    for i in countup(0, spendable.len - 1, 49):
        try:
            result.add(
                newSendInput(
                    spendable[i ..< i + 48].toHash(384),
                    int(spendable[i + 48])
                )
            )
        except ValueError as e:
            raise newException(DBReadError, e.msg)
