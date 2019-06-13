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

#Serialization libs.
import Serialize/Transactions/SerializeMintOutput
import Serialize/Transactions/SerializeSendOutput
import Serialize/Transactions/SerializeTransaction

import Serialize/Transactions/ParseMintOutput
import Serialize/Transactions/ParseSendOutput
import Serialize/Transactions/ParseTransaction

#DB object.
import objects/DBObj
export DBObj

#Put/Get/Delete for the Transactions DB.
proc put(
    db: DB,
    key: string,
    val: string
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.lmdb.put("transactions", key, val)
    except Exception as e:
        raise newException(DBWriteError, e.msg)

proc get(
    db: DB,
    key: string
): string {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.lmdb.get("transactions", key)
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc delete(
    db: DB,
    key: string
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.lmdb.delete("transactions", key)
    except Exception as e:
        raise newException(DBWriteError, e.msg)

#Save functions.
proc save*(
    db: DB,
    tx: Transaction
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.put(tx.hash.toString(), tx.serialize())
    except DBWriteError as e:
        raise e

proc save*(
    db: DB,
    key: BLSPublicKey,
    height: int
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.put(key.toString() & "mh", height.toBinary())
    except DBWriteError as e:
        raise e

proc saveMintNonce*(
    db: DB,
    nonce: int
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.put("mint", nonce.toBinary())
    except DBWriteError as e:
        raise e

proc save*(
    db: DB,
    hash: Hash[384],
    utxo: MintOutput
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.put(hash.toString() & char(0), utxo.serialize())
    except DBWriteError as e:
        raise e

proc save*(
    db: DB,
    hashArg: Hash[384],
    utxos: seq[SendOutput]
) {.forceCheck: [
    DBWriteError
].} =
    var hash: string = hashArg.toString()
    for i in 0 ..< utxos.len:
        try:
            db.put(hash & char(i), utxos[i].serialize())
        except DBWriteError as e:
            raise e

#Delete functions.
proc deleteUTXO*(
    db: DB,
    hash: Hash[384]
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.delete(hash.toString() & char(0))
    except DBWriteError as e:
        fcRaise e

proc deleteUTXO*(
    db: DB,
    hash: Hash[384],
    nonce: int
) {.forceCheck: [
    DBWriteError
].} =
    try:
        db.delete(hash.toString() & char(nonce))
    except DBWriteError as e:
        fcRaise e

#Load functions.
proc load*(
    db: DB,
    hash: Hash[384]
): Transaction {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(hash.toString()).parseTransaction()
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
): int {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get("mint").fromBinary()
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

proc commit*(
    db: DB
) {.forceCheck: [].} =
    discard
