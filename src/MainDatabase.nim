include MainGlobals

proc mainDatabase() {.raises: [LMDBError].} =
    {.gcsafe.}:
        #Open the database.
        db = newDB(config.db, MAX_DB_SIZE)

        #Allow access to put/get/delete.
        functions.database.put = proc (key: string, val: string) {.raises: [LMDBError].} =
            try:
                db.put(key, val)
            except:
                raise newException(LMDBError, getCurrentExceptionMsg())

        functions.database.get = proc (key: string): string {.raises: [LMDBError].} =
            try:
                result = db.get(key)
            except:
                raise newException(LMDBError, getCurrentExceptionMsg())

        functions.database.delete = proc (key: string) {.raises: [LMDBError].} =
            try:
                db.delete(key)
            except:
                raise newException(LMDBError, getCurrentExceptionMsg())
