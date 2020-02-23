#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
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

#Sets standard lib.
import sets

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
template UNMENTIONED_TRANSACTIONS(): string =
    "u"

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

template SPENDABLE(
    key: EdPublicKey
): string =
    key.toString() & "$p"

template BEATEN_TRANSACTION(
    hash: Hash[256]
): string =
    hash.toString() & "bt"

#Put/Get/Del/Commit for the Transactions DB.
proc put(
    db: DB,
    key: string,
    val: string
) {.forceCheck: [].} =
    db.transactions.cache[key] = val
    db.transactions.deleted.excl(key)

proc get(
    db: DB,
    key: string
): string {.forceCheck: [
    DBReadError
].} =
    if db.transactions.deleted.contains(key):
        raise newLoggedException(DBReadError, "Key deleted.")

    if db.transactions.cache.hasKey(key):
        try:
            return db.transactions.cache[key]
        except KeyError as e:
            panic("Couldn't get a key from a table confirmed to exist: " & e.msg)

    try:
        result = db.lmdb.get("transactions", key)
    except Exception as e:
        raise newLoggedException(DBReadError, e.msg)

proc del(
    db: DB,
    key: string
) {.forceCheck: [].} =
    db.transactions.deleted.incl(key)
    db.transactions.cache.del(key)

proc commit*(
    db: DB
) {.forceCheck: [].} =
    for key in db.transactions.deleted:
        try:
            db.lmdb.delete("transactions", key)
        except Exception:
            #If we delete something before it's committed, it'll throw.
            discard
    db.transactions.deleted = initHashSet[string]()

    var items: seq[tuple[key: string, value: string]] = newSeq[tuple[key: string, value: string]](db.transactions.cache.len + 1)
    try:
        var i: int = 0
        for key in db.transactions.cache.keys():
            items[i] = (key: key, value: db.transactions.cache[key])
            inc(i)
    except KeyError as e:
        panic("Couldn't get a value from the table despiting getting the key from .keys(): " & e.msg)

    var unmentioned: string
    for hash in db.transactions.unmentioned:
        unmentioned &= hash.toString()
    items[^1] = (key: UNMENTIONED_TRANSACTIONS(), value: unmentioned)

    try:
        db.lmdb.put("transactions", items)
    except Exception as e:
        panic("Couldn't save data to the Database: " & e.msg)

    db.transactions.cache = initTable[string, string]()

#Save functions.
proc save*(
    db: DB,
    tx: Transaction
) {.forceCheck: [].} =
    db.put(TRANSACTION(tx.hash), tx.serialize())
    db.transactions.unmentioned.incl(tx.hash)

    if not ((tx of Data) and (tx.inputs[0].hash == Hash[256]())):
        for input in tx.inputs:
            try:
                db.put(OUTPUT_SPENDERS(input), db.get(OUTPUT_SPENDERS(input)) & tx.hash.toString())
            except DBReadError:
                db.put(OUTPUT_SPENDERS(input), tx.hash.toString())

    for o in 0 ..< tx.outputs.len:
        db.put(OUTPUT(tx.hash, o), tx.outputs[o].serialize())

proc mention*(
    db: DB,
    hash: Hash[256]
) {.forceCheck: [].} =
    db.transactions.unmentioned.excl(hash)

proc unmention*(
    db: DB,
    hashes: HashSet[Hash[256]]
) {.inline, forceCheck: [].} =
    db.transactions.unmentioned = db.transactions.unmentioned + hashes

proc saveDataSender*(
    db: DB,
    data: Data,
    sender: EdPublicKey
) {.forceCheck: [].} =
    db.put(DATA_SENDER(data.hash), sender.toString())

#Load functions.
proc loadUnmentioned*(
    db: DB
): HashSet[Hash[256]] {.forceCheck: [].} =
    var unmentioned: string
    try:
        unmentioned = db.get(UNMENTIONED_TRANSACTIONS())
    except DBReadError:
        return

    result = initHashSet[Hash[256]]()
    for h in 0 ..< unmentioned.len div 32:
        try:
            result.incl(unmentioned[h * 32 ..< (h + 1) * 32].toHash(256))
        except ValueError as e:
            panic("Couldn't create a 32-byte hash out of a 32-byte value: " & e.msg)
    db.transactions.unmentioned = result

proc load*(
    db: DB,
    hash: Hash[256]
): Transaction {.forceCheck: [
    DBReadError
].} =
    try:
        result = hash.parseTransaction(db.get(TRANSACTION(hash)))
    except Exception as e:
        raise newLoggedException(DBReadError, e.msg)

    #Recalculate the output amount if this is a Claim.
    if result of Claim:
        var
            claim: Claim = cast[Claim](result)
            amount: uint64 = 0
        for input in claim.inputs:
            try:
                amount += db.get(OUTPUT(input)).parseMintOutput().amount
            except Exception as e:
                panic("Claim's spent Mints' outputs couldn't be loaded from the DB: " & e.msg)

        claim.outputs[0].amount = amount

#Get if a Transaction was beaten.
proc isBeaten*(
    db: DB,
    hash: Hash[256]
): bool {.forceCheck: [].} =
    try:
        discard db.get(BEATEN_TRANSACTION(hash))
        result = true
    except DBReadError:
        result = false

proc loadSpenders*(
    db: DB,
    input: Input
): seq[Hash[256]] {.forceCheck: [].} =
    var spenders: string = ""
    try:
        spenders = db.get(OUTPUT_SPENDERS(input))
    except DBReadError:
        return

    for h in countup(0, spenders.len - 1, 32):
        try:
            result.add(spenders[h ..< h + 32].toHash(256))
        except ValueError as e:
            panic("Couldn't load a spending hash from the DB: " & e.msg)

proc loadDataSender*(
    db: DB,
    hash: Hash[256]
): EdPublicKey {.forceCheck: [
    DBReadError
].} =
    try:
        result = newEdPublicKey(db.get(DATA_SENDER(hash)))
    except Exception as e:
        raise newLoggedException(DBReadError, e.msg)

proc loadMintOutput*(
    db: DB,
    input: FundedInput
): MintOutput {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(OUTPUT(input)).parseMintOutput()
    except Exception as e:
        raise newLoggedException(DBReadError, e.msg)

proc loadSendOutput*(
    db: DB,
    input: FundedInput
): SendOutput {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(OUTPUT(input)).parseSendOutput()
    except Exception as e:
        raise newLoggedException(DBReadError, e.msg)

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
        raise newLoggedException(DBReadError, e.msg)

    for i in countup(0, spendable.len - 1, 33):
        try:
            result.add(
                newFundedInput(
                    spendable[i ..< i + 32].toHash(256),
                    int(spendable[i + 32])
                )
            )
        except ValueError as e:
            raise newLoggedException(DBReadError, e.msg)

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
        panic("Trying to spend from someone without anything spendable.")

    #Remove the specified output.
    for o in countup(0, spendable.len - 1, 33):
        if spendable[o ..< o + 33] == output:
            db.put(SPENDABLE(key), spendable[0 ..< o] & spendable[o + 33 ..< spendable.len])
            break

#Add a outputs to spendable while removing spent inputs.
proc verify*(
    db: DB,
    tx: Transaction
) {.forceCheck: [].} =
    #Add spendable outputs.
    if (tx of Claim) or (tx of Send):
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
                    panic("Removing a non-existent output.")

                db.removeFromSpendable(
                    key,
                    input.hash,
                    cast[FundedInput](input).nonce
                )

#Add a inputs back to spendable while removing unverified outputs.
proc unverify*(
    db: DB,
    tx: Transaction
) {.forceCheck: [].} =
    if (tx of Claim) or (tx of Send):
        #Remove outputs.
        for o in 0 ..< tx.outputs.len:
            db.removeFromSpendable(
                cast[SendOutput](tx.outputs[o]).key,
                tx.hash,
                o
            )

        #Restore inputs.
        if tx of Send:
            for input in tx.inputs:
                var key: EdPublicKey
                try:
                    key = db.loadSendOutput(cast[FundedInput](input)).key
                except DBReadError:
                    panic("Restoring a non-existent output.")

                db.addToSpendable(
                    key,
                    input.hash,
                    cast[FundedInput](input).nonce
                )

#Mark a Transaction as beaten.
proc beat*(
    db: DB,
    hash: Hash[256]
) {.forceCheck: [].} =
    db.put(BEATEN_TRANSACTION(hash), "")

#Prune a Transaction.
proc prune*(
    db: DB,
    hash: Hash[256]
) {.forceCheck: [].} =
    #Get the TX.
    var tx: Transaction
    try:
        tx = db.load(hash)
    except DBReadError:
        return

    #Delete the Transaction.
    db.del(TRANSACTION(hash))

    #Delete if it was beaten.
    db.del(BEATEN_TRANSACTION(hash))

    #Delete if its unmentioned.
    db.transactions.unmentioned.excl(hash)

    #Remove it as a spender.
    var hashStr: string = hash.toString()
    for i in 0 ..< tx.inputs.len:
        var spenders: string
        try:
            spenders = db.get(OUTPUT_SPENDERS(tx.inputs[i]))
        except DBReadError as e:
            panic("Couldn't get the spenders of a spent input: " & e.msg)

        for h in countup(0, spenders.len - 1, 32):
            if spenders[h ..< h + 32] == hashStr:
                spenders = spenders[0 ..< h] & spenders[h + 32 ..< spenders.len]
                break

        db.put(OUTPUT_SPENDERS(tx.inputs[i]), spenders)

        #If we were the only spender of this output, restore the output as spendable.
        if (spenders.len == 0) and (tx of Send):
            try:
                db.addToSpendable(
                    cast[SendOutput](
                        db.load(tx.inputs[i].hash).outputs[cast[FundedInput](tx.inputs[i]).nonce]
                    ).key,
                    tx.inputs[i].hash,
                    cast[FundedInput](tx.inputs[i]).nonce
                )
            except DBReadError:
                panic("Couldn't load the Transaction the Transaction we're pruning spent.")

    for o in 0 ..< tx.outputs.len:
        #Delete its outputs and their spenders.
        db.del(OUTPUT(hash, o))
        var spenders: string
        try:
            spenders = db.get(OUTPUT_SPENDERS(newFundedInput(hash, o)))
        except DBReadError:
            discard
        db.del(OUTPUT_SPENDERS(newFundedInput(hash, o)))

        #If it has no spenders and is tracked by spendable, remove it.
        if (spenders == "") and (tx.outputs[o] of SendOutput):
            db.removeFromSpendable(cast[SendOutput](tx.outputs[o]).key, hash, o)
