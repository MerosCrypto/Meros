#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet libs.
import ../../../Wallet/MinerWallet
import ../../../Wallet/Wallet

#Transaction object.
import ../../Transactions/objects/TransactionObj

#Epoch object.
import ../../Merit/objects/EpochsObj

#SerializeCommon lib.
import ../../../Network/Serialize/SerializeCommon

#Input toString function.
from ../DB/TransactionsDB import toString

#DB lib.
import mc_lmdb

#Tables standard lib.
import tables

#Key generators.
template MNEMONIC(): string =
    "w"

template DATA_TIP(): string =
    "d"

template MINER_KEY(): string =
    "m"

template MINER_NICK(): string =
    "n"

template INPUT_NONCE(
    nonce: int
): string =
    nonce.toBinary(INT_LEN)

template FINALIZED_NONCES(): string =
    "fn"

template UNFINALIZED_NONCES(): string =
    "un"

template ELEMENT_NONCE(): string =
    "e"

template USING_ELEMENT_NONCE(): string =
    "u"

#WalletDB.
type WalletDB* = ref object
    lmdb: LMDB

    wallet*: Wallet
    miner*: MinerWallet

    when defined(merosTests):
        finalizedNonces*: int
        unfinalizedNonces*: int
        verified*: Table[string, int]

        elementNonce*: int
    else:
        finalizedNonces: int
        unfinalizedNonces: int
        verified: Table[string, int]

        elementNonce: int

#Put/Get/Delete/Commit for the Wallet DB.
proc put(
    db: WalletDB,
    key: string,
    val: string
) {.forceCheck: [].} =
    try:
        db.lmdb.put("", @[(key, val)])
    except Exception as e:
        panic("Couldn't save data to the Database: " & e.msg)

proc put(
    db: WalletDB,
    items: seq[tuple[key: string, value: string]]
) {.forceCheck: [].} =
    try:
        db.lmdb.put("", items)
    except Exception as e:
        panic("Couldn't save data to the Database: " & e.msg)

proc get(
    db: WalletDB,
    key: string
): string {.forceCheck: [
    DBReadError
].} =
    try:
        result = db.lmdb.get("", key)
    except Exception as e:
        raise newLoggedException(DBReadError, e.msg)

proc del(
    db: WalletDB,
    key: string
) {.forceCheck: [].} =
    try:
        db.lmdb.delete("", key)
    except Exception as e:
        panic("Couldn't delete data from the Database: " & e.msg)

proc commit*(
    db: WalletDB,
    popped: Epoch,
    getTransaction: proc (
        hash: Hash[256]
    ): Transaction {.gcsafe, raises: [
        IndexError
    ].}
) {.gcsafe, forceCheck: [].} =
    #Mark all inputs of all finalized Transactions as finalized.
    var items: seq[tuple[key: string, value: string]] = newSeq[tuple[key: string, value: string]]()
    for hash in popped.keys():
        var tx: Transaction
        try:
            tx = getTransaction(hash)
        except IndexError as e:
            panic("Couldn't get a Transaction that's now out of Epochs: " & e.msg)

        for input in tx.inputs:
            try:
                items.add((INPUT_NONCE(db.verified[input.toString()]), char(1) & input.toString()))
                #If the nonce of this input is the same as the last finalized nonce, increment.
                if db.verified[input.toString()] == db.finalizedNonces:
                    inc(db.finalizedNonces)
                db.verified.del(input.toString())
            #We never verified a Transaction spending this input.
            except KeyError:
                continue
    db.put(items)

    #To handle out of order finalizations, do one last pass through.
    for n in db.finalizedNonces ..< db.unfinalizedNonces:
        try:
            if int(db.get(INPUT_NONCE(n))[0]) == 0:
                break
            inc(db.finalizedNonces)
        except DBReadError as e:
            panic("Couldn't get an input by its nonce: " & e.msg)

    #This is finalized outside of the singular Transaction as:
    #1) finalizedNonces is an optimation, not a requirement.
    #2) We need to read data we just modified in the Transaction.
    db.put(FINALIZED_NONCES(), db.finalizedNonces.toBinary)

#Constructor.
proc newWalletDB*(
    path: string,
    size: int64
): WalletDB {.forceCheck: [
    DBError
].} =
    try:
        result = WalletDB(
            lmdb: newLMDB(path, size, 1),

            wallet: newWallet(""),
            miner: newMinerWallet(),

            finalizedNonces: 0,
            unfinalizedNonces: 0,
            verified: initTable[string, int](),

            elementNonce: 0
        )
        result.lmdb.open()
    except Exception as e:
        raise newLoggedException(DBError, "Couldn't open the WalletDB: " & e.msg)

    #Load the Wallet.
    try:
        result.wallet = newWallet(result.get(MNEMONIC()), "")
    except ValueError as e:
        panic("Failed to load the Wallet from the Database: " & e.msg)
    except DBReadError:
        result.put(MNEMONIC(), $result.wallet.mnemonic)

    #Load the MinerWallet.
    try:
        result.miner = newMinerWallet(result.get(MINER_KEY()))
    except BLSError as e:
        panic("Failed to load the MinerWallet from the Database: " & e.msg)
    except DBReadError:
        result.put(MINER_KEY(), result.miner.privateKey.serialize())

    try:
        result.miner.nick = uint16(result.get(MINER_NICK()).fromBinary())
        result.miner.initiated = true
    except DBReadError:
        discard

    #Load the input nonces.
    try:
        result.unfinalizedNonces = result.get(UNFINALIZED_NONCES()).fromBinary()
        result.finalizedNonces = result.get(FINALIZED_NONCES()).fromBinary()
    except DBReadError:
        discard

    #Load the verified Table.
    for n in result.finalizedNonces ..< result.unfinalizedNonces:
        var input: string
        try:
            input = result.get(INPUT_NONCE(n))
        except DBReadError as e:
            panic("Couldn't get an input by its nonce: " & e.msg)

        if int(input[0]) == 1:
            continue

        result.verified[input[1 ..< 34]] = n

    #Load the Element nonce.
    try:
        #See getNonces for why this check exists.
        discard result.get(USING_ELEMENT_NONCE)
        panic("Node was terminated in the middle of creating a new Element.")
    except DBReadError:
        discard
    try:
        result.elementNonce = result.get(ELEMENT_NONCE()).fromBinary()
    except DBReadError:
        discard

#Close the DB.
proc close*(
    db: WalletDB
) {.forceCheck: [
    DBError
].} =
    try:
        db.lmdb.close()
    except Exception as e:
        raise newLoggedException(DBError, "Couldn't close the WalletDB: " & e.msg)

#Set the Wallet's mnemonic.
proc setWallet*(
    db: WalletDB,
    mnemonic: string,
    password: string
) {.forceCheck: [
    ValueError
].} =
    if mnemonic.len == 0:
        db.wallet = newWallet(password)
    else:
        try:
            db.wallet = newWallet(mnemonic, password)
        except ValueError as e:
            raise e

    db.put(MNEMONIC(), $db.wallet.mnemonic)

#Set the miner's nick.
proc setMinerNick*(
    db: WalletDB,
    nick: uint16
) {.forceCheck: [].} =
    db.miner.nick = nick
    db.miner.initiated = true
    db.put(MINER_KEY(), db.miner.privateKey.serialize())
    db.put(MINER_NICK(), nick.toBinary())

#Save our latest Data tip.
proc saveDataTip*(
    db: WalletDB,
    hash: Hash[256]
) {.forceCheck: [].} =
    db.put(DATA_TIP(), hash.toString())

#Load our latest Data tip.
proc loadDataTip*(
    db: WalletDB
): Hash[256] {.forceCheck: [
    DataMissing
].} =
    try:
        result = db.get(DATA_TIP()).toHash(256)
    except ValueError as e:
        panic("Couldn't parse the data tip from the WalletDB: " & e.msg)
    except DBReadError:
        raise newLoggedException(DataMissing, "No Data Tip available.")

#Mark that we're verifying a Transaction.
#Assumes if the function completes, the input was used.
#If the function doesn't complete, none of its data is written.
proc verifyTransaction*(
    db: WalletDB,
    tx: Transaction
) {.forceCheck: [
    ValueError
].} =
    #If we've already verified a Transaction sharing any inputs, raise.
    for input in tx.inputs:
        if db.verified.hasKey(input.toString()):
            raise newLoggedException(ValueError, "Verified a competing Transaction.")

    var items: seq[tuple[key: string, value: string]] = newSeq[tuple[key: string, value: string]]()
    for input in tx.inputs:
        #Ignore initial Data inputs.
        if input.hash == Hash[256]():
            continue

        #Save the input to the nonce.
        items.add((INPUT_NONCE(db.unfinalizedNonces), char(0) & input.toString()))
        db.verified[input.toString()] = db.unfinalizedNonces
        inc(db.unfinalizedNonces)
    #Save the nonce count.
    items.add((UNFINALIZED_NONCES(), db.unfinalizedNonces.toBinary()))
    db.put(items)

#Get a nonce for use in an Element.
#Unable to assume if the function completes, the nonce was used.
#The nonce may have been used or may not have been.
#Best case in that circumstance is a halted Element chain; worst case is a Merit Removal.
proc getNonce*(
    db: WalletDB
): int {.forceCheck: [].} =
    db.put(USING_ELEMENT_NONCE(), "")
    result = db.elementNonce
    inc(db.elementNonce)
    db.put(ELEMENT_NONCE(), db.elementNonce.toBinary())

#Mark the nonce as used.
proc useNonce*(
    db: WalletDB
) {.forceCheck: [].} =
    db.del(USING_ELEMENT_NONCE())
