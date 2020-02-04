#Errors lib.
import ../../../../lib/Errors

#Hash lib.
import ../../../../lib/Hash

#DB lib.
import mc_lmdb
export put, get, delete

#Sets standard lib.
import sets

#Tables standard lib.
import tables

type
    TransactionsDB* = ref object
        cache*: Table[string, string]
        deleted*: HashSet[string]

    ConsensusDB* = ref object
        cache*: Table[string, string]
        deleted*: HashSet[string]
        malicious*: set[uint16]
        unmentioned*: HashSet[Hash[256]]

    MeritDB* = ref object
        cache*: Table[string, string]
        deleted*: HashSet[string]
        removals*: Table[uint16, int]
        when defined(merosTests):
            used*: HashSet[string]

    DB* = ref object
        lmdb*: LMDB
        transactions*: TransactionsDB
        consensus*: ConsensusDB
        merit*: MeritDB

#Constructors.
proc newTransactionsDB(): TransactionsDB {.inline, forceCheck: [].} =
    TransactionsDB(
        cache: initTable[string, string](),
        deleted: initHashSet[string]()
    )

proc newConsensusDB(): ConsensusDB {.inline, forceCheck: [].} =
    ConsensusDB(
        cache: initTable[string, string](),
        deleted: initHashSet[string](),
        malicious: {},
        unmentioned: initHashSet[Hash[256]]()
    )

proc newMeritDB(): MeritDB {.inline, forceCheck: [].} =
    when not defined(merosTests):
        MeritDB(
            cache: initTable[string, string](),
            deleted: initHashSet[string](),
            removals: initTable[uint16, int]()
        )
    else:
        MeritDB(
            cache: initTable[string, string](),
            deleted: initHashSet[string](),
            removals: initTable[uint16, int](),
            used: initHashSet[string]()
        )

proc newDB*(
    path: string,
    size: int64
): DB {.forceCheck: [
    DBError
].} =
    try:
        result = DB(
            lmdb: newLMDB(path, size, 3),
            transactions: newTransactionsDB(),
            consensus: newConsensusDB(),
            merit: newMeritDB()
        )
        result.lmdb.open("transactions")
        result.lmdb.open("consensus")
        result.lmdb.open("merit")
    except Exception as e:
        raise newLoggedException(DBError, "Couldn't open the DB: " & e.msg)

proc close*(
    db: DB
) {.forceCheck: [
    DBError
].} =
    try:
        db.lmdb.close()
    except Exception as e:
        raise newLoggedException(DBError, "Couldn't close the DB: " & e.msg)
