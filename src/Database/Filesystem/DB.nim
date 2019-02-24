#LMDB wrapper.
import mc_lmdb
export get, put, delete, close

#Rename LMDB to DB.
type DB* = LMDB
proc newDB*(path: string): DB {.raises: [LMDBError].} =
    newLMDB(path)
