#Errors lib.
import ../../../../lib/Errors

#DB lib.
import mc_lmdb
export get, put

#Tables standard lib.
import tables

type
    DB* = ref object
        lmdb*: LMDB
        transactions*: Table[string, string]
        consensus*: Table[string, string]
        merit*: Table[string, string]

#Constructor.
proc newDB*(
    path: string,
    size: int64
): DB {.forceCheck: [
    DBError
].} =
    try:
        result = DB(
            lmdb: newLMDB(path, size, 3),
            transactions: initTable[string, string](),
            consensus: initTable[string, string](),
            merit: initTable[string, string]()
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
