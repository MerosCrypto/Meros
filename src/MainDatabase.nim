include MainLattice

proc MainDatabase() {.raises: [LMDBError].} =
    {.gcsafe.}:
        #Open the database.
        db = newDB(config.db)

        #Allow access to put/get/delete.
        functions.database.put = proc (db: DB, key: string, val: string) {.raises: [LMDBError].} =
            try:
                db.put(key, val)
            except:
                raise newException(LMDBError, getCurrentExceptionMsg())

        functions.database.get = proc (db: DB, key: string): string {.raises: [LMDBError].} =
            try:
                result = db.get(key)
            except:
                raise newException(LMDBError, getCurrentExceptionMsg())

        functions.database.delete = proc (db: DB, key: string) {.raises: [LMDBError].} =
            try:
                db.delete(key)
            except:
                raise newException(LMDBError, getCurrentExceptionMsg())
