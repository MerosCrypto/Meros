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
import ../../../Network/Serialize/SerializeCommon

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

#Helper function to convert an input to a string.
func toString*(
    input: Input
): string {.forceCheck: [].} =
    result = input.hash.toString()
    if input of FundedInput:
        result &= char(cast[FundedInput](input).nonce)
    else:
        result &= char(0)

#Key generators.
template TRANSACTION(
    hash: Hash[256]
): string =
    hash.toString()

template OUTPUT_SPENDERS(
    input: Input
): string =
    input.toString() & "$"

template OUTPUT(
    hash: Hash[256],
    o: int
): string =
    hash.toString() & o.toBinary(BYTE_LEN)

template OUTPUT(
    output: Input
): string =
    input.toString()

template DATA_SENDER(
    hash: Hash[256]
): string =
    hash.toString() & "se"

template DATA_TIP(
    key: EdPublicKey
): string =
    key.toString() & "dt"

template SPENDABLE(
    key: EdPublicKey
): string =
    key.toString() & "$p"

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

#Save functions.
proc save*(
    db: DB,
    tx: Transaction
) {.forceCheck: [].} =
    db.put(TRANSACTION(tx.hash), tx.serialize())

    for input in tx.inputs:
        try:
            db.put(OUTPUT_SPENDERS(input), db.get(OUTPUT_SPENDERS(input)) & tx.hash.toString())
        except DBReadError:
            db.put(OUTPUT_SPENDERS(input), tx.hash.toString())

    for o in 0 ..< tx.outputs.len:
        db.put(OUTPUT(tx.hash, o), tx.outputs[o].serialize())

proc saveDataSender*(
    db: DB,
    data: Data,
    sender: EdPublicKey
) {.forceCheck: [].} =
    db.put(DATA_SENDER(data.hash), sender.toString())

proc saveDataTip*(
    db: DB,
    key: EdPublicKey,
    hash: Hash[256]
) {.forceCheck: [].} =
    db.put(DATA_TIP(key), hash.toString())

#Load functions.
proc load*(
    db: DB,
    hash: Hash[256]
): Transaction {.forceCheck: [
    DBReadError
].} =
    try:
        result = hash.parseTransaction(db.get(TRANSACTION(hash)))
    except Exception as e:
        raise newException(DBReadError, e.msg)

    #Recalculate the output amount if this is a Claim.
    if result of Claim:
        var
            claim: Claim = cast[Claim](result)
            amount: uint64 = 0
        for input in claim.inputs:
            try:
                amount += db.get(OUTPUT(input)).parseMintOutput().amount
            except Exception as e:
                doAssert(false, "Claim's spent Mints' outputs couldn't be loaded from the DB: " & e.msg)

        claim.outputs[0].amount = amount

proc loadSpenders*(
    db: DB,
    input: Input
): seq[Hash[256]] {.forceCheck: [].} =
    var spenders: string = ""
    try:
        spenders = db.get(OUTPUT(input) & "s")
    except DBReadError:
        return

    for h in countup(0, spenders.len - 1, 32):
        try:
            result.add(spenders[h ..< h + 32].toHash(256))
        except ValueError as e:
            doAssert(false, "Couldn't load a spending hash from the DB: " & e.msg)

proc loadDataSender*(
    db: DB,
    hash: Hash[256]
): EdPublicKey {.forceCheck: [
    DBReadError
].} =
    try:
        result = newEdPublicKey(db.get(DATA_SENDER(hash)))
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadMintOutput*(
    db: DB,
    input: FundedInput
): MintOutput {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(OUTPUT(input)).parseMintOutput()
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadSendOutput*(
    db: DB,
    input: FundedInput
): SendOutput {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(OUTPUT(input)).parseSendOutput()
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc loadDataTip*(
    db: DB,
    key: EdPublicKey
): Hash[256] {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(DATA_TIP(key)).toHash(256)
    except DBReadError as e:
        raise e
    except ValueError as e:
        raise newException(DBReadError, e.msg)

proc loadSpendable*(
    db: DB,
    key: EdPublicKey
): seq[FundedInput] {.forceCheck: [
    DBReadError
].} =
    var spendable: string
    try:
        spendable = db.get(SPENDABLE(key))
    except Exception as e:
        raise newException(DBReadError, e.msg)

    for i in countup(0, spendable.len - 1, 33):
        try:
            result.add(
                newFundedInput(
                    spendable[i ..< i + 32].toHash(256),
                    int(spendable[i + 32])
                )
            )
        except ValueError as e:
            raise newException(DBReadError, e.msg)

proc addToSpendable(
    db: DB,
    key: EdPublicKey,
    hash: Hash[256],
    nonce: int
) {.forceCheck: [].} =
    try:
        db.put(SPENDABLE(key), db.get(SPENDABLE(key)) & hash.toString() & char(nonce))
    except DBReadError:
        db.put(SPENDABLE(key), hash.toString() & char(nonce))

proc removeFromSpendable(
    db: DB,
    key: EdPublicKey,
    hash: Hash[256],
    nonce: int
) {.forceCheck: [].} =
    var
        output: string = hash.toString() & char(nonce)
        spendable: string

    #Load the output.
    try:
        spendable = db.get(SPENDABLE(key))
    except DBReadError:
        doAssert(false, "Trying to spend from someone without anything spendable.")

    #Remove the specified output.
    for o in countup(0, spendable.len - 1, 33):
        if spendable[o ..< o + 33] == output:
            db.put(SPENDABLE(key), spendable[0 ..< o] & spendable[o + 33 ..< spendable.len])
            break

#Add a Claim/Send's outputs to spendable while removing a Send's inputs.
proc verify*(
    db: DB,
    tx: Claim or Send
) {.forceCheck: [].} =
    #Add spendable outputs.
    for o in 0 ..< tx.outputs.len:
        db.addToSpendable(
            cast[SendOutput](tx.outputs[o]).key,
            tx.hash,
            o
        )

    if tx of Send:
        #Remove spent inputs.
        for input in tx.inputs:
            var key: EdPublicKey
            try:
                key = db.loadSendOutput(cast[FundedInput](input)).key
            except DBReadError:
                doAssert(false, "Removing a non-existent output.")

            db.removeFromSpendable(
                key,
                input.hash,
                cast[FundedInput](input).nonce
            )

#Add a Send's inputs back to spendable while removing the Claim/Send's outputs.
proc unverify*(
    db: DB,
    tx: Claim or Send
) {.forceCheck: [].} =
    #Restore inputs.
    if tx of Send:
        for input in tx.inputs:
            var key: EdPublicKey
            try:
                key = db.loadSendOutput(cast[FundedInput](input)).key
            except DBReadError:
                doAssert(false, "Restoring a non-existent output.")

            db.addToSpendable(
                key,
                input.hash,
                cast[FundedInput](input).nonce
            )

    #Remove outputs.
    for o in 0 ..< tx.outputs.len:
        db.removeFromSpendable(
            cast[SendOutput](tx.outputs[o]).key,
            tx.hash,
            o
        )
