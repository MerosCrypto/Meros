#LMDB wrapper.
import mc_lmdb
export get, put, delete, close

#Rename LMDB to DB.
type DB* = LMDB
proc newDB*(path: string, size: int64): DB {.raises: [LMDBError].} =
    newLMDB(path, size)
