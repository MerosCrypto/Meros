#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Element lib.
import ../../Consensus/Element

#Serialize/parse libs.
import Serialize/Consensus/DBSerializeElement
import Serialize/Consensus/DBParseElement

import Serialize/Consensus/SerializeUnknown
import Serialize/Consensus/ParseUnknown

#DB object.
import objects/DBObj
export DBObj

#Tables standard lib.
import tables

#Put/Get/Delete/Commit for the Consensus DB.
proc put(
    db: DB,
    key: string,
    val: string
) {.forceCheck: [].} =
    db.consensus.cache[key] = val

proc get(
    db: DB,
    key: string
): string {.forceCheck: [
    DBReadError
].} =
    if db.consensus.cache.hasKey(key):
        try:
            return db.consensus.cache[key]
        except KeyError as e:
            doAssert(false, "Couldn't get a key from a table confirmed to exist: " & e.msg)

    try:
        result = db.lmdb.get("consensus", key)
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc delete(
    db: DB,
    key: string
) {.forceCheck: [].} =
    db.consensus.cache.del(key)
    db.consensus.deleted.add(key)

proc commit*(
    db: DB
) {.forceCheck: [].} =
    for key in db.consensus.deleted:
        try:
            db.lmdb.delete("consensus", key)
        except Exception:
            #If we delete something before it's committed, it'll throw.
            discard
    db.consensus.deleted = @[]

    for u in 0 ..< 5:
        db.consensus.cache["u" & char(u)] = db.consensus.unknown[u]

    var items: seq[tuple[key: string, value: string]] = newSeq[tuple[key: string, value: string]](db.consensus.cache.len)
    try:
        var i: int = 0
        for key in db.consensus.cache.keys():
            items[i] = (key: key, value: db.consensus.cache[key])
            inc(i)
    except KeyError as e:
        doAssert(false, "Couldn't get a value from the table despiting getting the key from .keys(): " & e.msg)

    try:
        db.lmdb.put("consensus", items)
    except Exception as e:
        doAssert(false, "Couldn't save data to the Database: " & e.msg)

    db.consensus.cache = initTable[string, string]()

#Save functions.
proc save*(
    db: DB,
    holder: BLSPublicKey,
    epoch: int
) {.forceCheck: [].} =
    var holderStr: string = holder.toString()

    try:
        discard db.consensus.holders[holderStr]
    except KeyError:
        db.consensus.holders[holderStr] = true
        db.consensus.holdersStr &= holderStr
        db.put("holders", db.consensus.holdersStr)

    db.put(holderStr, $epoch)

proc save*(
    db: DB,
    elem: Element
) {.forceCheck: [].} =
    db.put(
        elem.holder.toString() & elem.nonce.toBinary().pad(1),
        elem.serialize()
    )

proc saveUnknown*(
    db: DB,
    verif: Verification
) {.forceCheck: [].} =
    db.consensus.unknown[5] &= verif.serializeUnknown()

proc advanceUnknown*(
    db: DB
) {.forceCheck: [].} =
    for i in 0 ..< 5:
        db.consensus.unknown[i] = db.consensus.unknown[i + 1]
    db.consensus.unknown[5] = ""

proc loadHolders*(
    db: DB
): seq[string] {.forceCheck: [
    DBReadError
].} =
    try:
        db.consensus.holdersStr = db.get("holders")
    except DBReadError as e:
        fcRaise e

    result = newSeq[string](db.consensus.holdersStr.len div 48)
    for i in countup(0, db.consensus.holdersStr.len - 1, 48):
        result[i div 48] = db.consensus.holdersStr[i ..< i + 48]
        db.consensus.holders[db.consensus.holdersStr[i ..< i + 48]] = true

proc load*(
    db: DB,
    holder: BLSPublicKey
): int {.forceCheck: [
    DBReadError
].} =
    try:
        result = parseInt(db.get(holder.toString()))
    except Exception as e:
        raise newException(DBReadError, e.msg)

proc load*(
    db: DB,
    holder: BLSPublicKey,
    nonce: int
): Element {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.get(holder.toString() & nonce.toBinary().pad(1)).parseElement(holder, nonce)
    except Exception as e:
        raise newException(DBReadError, e.msg)

    if result of MeritRemoval:
        try:
            result.nonce = nonce
        except FinalAttributeError as e:
            doAssert(false, "Set a final attribute twice when loading a MeritRemoval: " & e.msg)

proc loadUnknown*(
    db: DB
): seq[seq[Verification]] {.forceCheck: [
    DBReadError
].} =
    var unknowns: string
    result = newSeq[seq[Verification]](5)
    for u in 0 ..< 5:
        try:
            unknowns = db.get("u" & char(u))
        except DBReadError as e:
            if u == 0:
                return
            else:
                fcRaise e

        for i in countup(0, unknowns.len - 1, UNKNOWN_LEN):
            try:
                result[u].add(unknowns[i ..< i + UNKNOWN_LEN].parseUnknown())
            except Exception as e:
                raise newException(DBReadError, e.msg)

#Delete an element.
proc del*(
    db: DB,
    key: BLSPublicKey,
    nonce: int
) {.forceCheck: [].} =
    db.delete(key.toString() & nonce.toBinary().pad(1))
