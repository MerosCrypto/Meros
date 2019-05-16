#Errors lib.
import ../../lib/Errors

#LMDB wrapper.
import mc_lmdb
export get, put, delete, close

#Rename LMDB to DB.
type DB* = LMDB
proc newDB*(
    path: string,
    size: int64,
    readers: int = 126
): DB {.forceCheck: [
    DBError
].} =
    try:
        result = newLMDB(path, size, readers)
    except LMDBError as e:
        raise newException(DBError, e.msg)
