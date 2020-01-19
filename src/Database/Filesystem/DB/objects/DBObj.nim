#Errors lib.
import ../../../../lib/Errors

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
        deleted*: seq[string]

    ConsensusDB* = ref object
        cache*: Table[string, string]
        deleted*: HashSet[string]
        malicious*: set[uint16]
        unmentioned*: string

    MeritDB* = ref object
        cache*: Table[string, string]
        removals*: Table[uint16, int]

    DB* = ref object
        lmdb*: LMDB
        transactions*: TransactionsDB
        consensus*: ConsensusDB
        merit*: MeritDB

#Constructors.
proc newTransactionsDB(): TransactionsDB {.inline, forceCheck: [].} =
    TransactionsDB(
        cache: initTable[string, string](),
        deleted: @[]
    )
proc newConsensusDB(): ConsensusDB {.inline, forceCheck: [].} =
    ConsensusDB(
        cache: initTable[string, string](),
        deleted: initHashSet[string](),
        malicious: {},
        unmentioned: ""
    )
proc newMeritDB(): MeritDB {.inline, forceCheck: [].} =
    MeritDB(
        cache: initTable[string, string](),
        removals: initTable[uint16, int]()
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
        raise newException(DBError, "Couldn't open the DB: " & e.msg)

proc close*(
    db: DB
) {.forceCheck: [
    DBError
].} =
    try:
        db.lmdb.close()
    except Exception as e:
        raise newException(DBError, "Couldn't close the DB: " & e.msg)
