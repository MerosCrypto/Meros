#Errors lib.
import ../../../../lib/Errors

#DB lib.
import mc_lmdb
export put, get, delete

#Tables standard lib.
import tables

type
    TransactionsDB* = ref object
        cache*: Table[string, string]
        deleted*: seq[string]

    ConsensusDB* = ref object
        cache*: Table[string, string]
        deleted*: seq[string]
        holders*: Table[string, bool]
        holdersStr*: string

    MeritDB* = ref object
        cache*: Table[string, string]
        holders*: Table[string, bool]
        removals*: Table[string, int]
        holdersStr*: string

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
        deleted: @[],
        holders: initTable[string, bool]()
    )
proc newMeritDB(): MeritDB {.inline, forceCheck: [].} =
    MeritDB(
        cache: initTable[string, string](),
        holders: initTable[string, bool](),
        removals: initTable[string, int]()
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
