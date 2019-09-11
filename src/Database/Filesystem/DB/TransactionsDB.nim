#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet libs.
import ../../../Wallet/MinerWallet
import ../../../Wallet/Wallet

#Transaction lib.
import ../../Transactions/Transaction

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

proc commit*(
    db: DB
) {.forceCheck: [].} =
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

#Helper functions to convert an input to a string.
func toString*(
    input: Input
): string {.forceCheck: [].} =
    result = input.hash.toString()
    if input of SendInput:
        result &= char(cast[SendInput](input).nonce)
    else:
        result &= char(0)

#Save functions.
proc save*(
    db: DB,
    tx: Transaction
) {.forceCheck: [].} =
    var hash: string = tx.hash.toString()
    db.put(hash, tx.serialize())

    if tx of Mint:
        db.put("mint", (cast[Mint](tx).nonce + 1).toBinary())
    else:
        for input in tx.inputs:
            try:
                db.put(input.toString() & "s", db.get(input.toString() & "s") & hash)
            except DBReadError:
                db.put(input.toString() & "s", hash)

    for o in 0 ..< tx.outputs.len:
        db.put(hash & char(o), tx.outputs[o].serialize())

proc saveDataSender*(
    db: DB,
    data: Data,
    sender: EdPublicKey
) {.forceCheck: [].} =
    db.put(data.hash.toString() & "s", sender.toString())

proc save*(
    db: DB,
    key: BLSPublicKey,
    height: int
) {.forceCheck: [].} =
    db.put(key.toString() & "mh", height.toBinary())

proc saveDataTip*(
    db: DB,
    key: EdPublicKey,
    hash: Hash[384]
) {.forceCheck: [].} =
    db.put(key.toString() & "d", hash.toString())

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

    #Recalculate the output amount if this is a Claim.
    if result of Claim:
        var
            claim: Claim = cast[Claim](result)
            amount: uint64 = 0
        for input in claim.inputs:
            try:
                amount += db.get(input.toString()).parseMintOutput().amount
            except Exception as e:
                doAssert(false, "Claim's spent Mints' outputs couldn't be loaded from the DB: " & e.msg)

        try:
            claim.outputs[0].amount = amount
        except FinalAttributeError as e:
            doAssert(false, "Set a final attribute twice when reloading a Claim: " & e.msg)

proc loadSpenders*(
    db: DB,
    input: Input
): seq[Hash[384]] {.forceCheck: [].} =
    var spenders: string = ""
    try:
        spenders = db.get(input.toString() & "s")
    except DBReadError:
        return

    for h in countup(0, spenders.len - 1, 48):
        try:
            result.add(spenders[h ..< h + 48].toHash(384))
        except ValueError as e:
            doAssert(false, "Couldn't load a spending hash from the DB: " & e.msg)

proc loadDataSender*(
    db: DB,
    hash: Hash[384]
): EdPublicKey {.forceCheck: [
    DBReadError
].} =
    try:
        result = newEdPublicKey(db.get(hash.toString() & "s"))
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

proc loadMintOutput*(
    db: DB,
    hash: Hash[384]
): MintOutput {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(hash.toString() & char(0)).parseMintOutput()
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadSendOutput*(
    db: DB,
    input: SendInput
): SendOutput {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(input.toString()).parseSendOutput()
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadDataTip*(
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

proc addToSpendable(
    db: DB,
    key: string,
    hash: Hash[384],
    nonce: int
) {.forceCheck: [].} =
    try:
        db.put(key, db.get(key) & hash.toString() & char(nonce))
    except DBReadError:
        db.put(key, "" & hash.toString() & char(nonce))

proc removeFromSpendable(
    db: DB,
    key: string,
    hash: Hash[384],
    nonce: int
) {.forceCheck: [].} =
    var
        output: string = hash.toString() & char(nonce)
        spendable: string

    #Load the output.
    try:
        spendable = db.get(key)
    except DBReadError:
        doAssert(false, "Trying to spend from someone without anything spendable.")

    #Remove the specified output.
    for o in countup(0, spendable.len, 49):
        if spendable[o ..< o + 49] == output:
            db.put(key, spendable[0 ..< o] & spendable[o + 49 ..< spendable.len])
            break

#Add a Claim/Send's outputs to spendable while removing a Send's inputs.
proc verify*(
    db: DB,
    tx: Claim or Send
) {.forceCheck: [].} =
    #Add spendable outputs.
    for o in 0 ..< tx.outputs.len:
        db.addToSpendable(
            cast[SendOutput](tx.outputs[o]).key.toString(),
            tx.hash,
            o
        )

    if tx of Send:
        #Remove spent inputs.
        for input in tx.inputs:
            var key: string
            try:
                key = db.loadSendOutput(cast[SendInput](input)).key.toString()
            except DBReadError:
                doAssert(false, "Removing a non-existent output.")

            db.removeFromSpendable(
                key,
                input.hash,
                cast[SendInput](input).nonce
            )

#Add a Send's inputs back to spendable while removing the Claim/Send's outputs.
proc unverify*(
    db: DB,
    tx: Claim or Send
) {.forceCheck: [].} =
    #Restore inputs.
    if tx of Send:
        for input in tx.inputs:
            var key: string
            try:
                key = db.loadSendOutput(cast[SendInput](input)).key.toString()
            except DBReadError:
                doAssert(false, "Restoring a non-existent output.")

            db.addToSpendable(
                key,
                input.hash,
                cast[SendInput](input).nonce
            )

    #Remove outputs.
    for o in 0 ..< tx.outputs.len:
        db.removeFromSpendable(
            cast[SendOutput](tx.outputs[o]).key.toString(),
            tx.hash,
            o
        )
