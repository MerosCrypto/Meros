include MainGlobals

proc mainDatabase() {.forceCheck: [
    DBError
].} =
    {.gcsafe.}:
        #Open the database.
        try:
            db = newDB(config.db, MAX_DB_SIZE)
        except DBError as e:
            raise e

        #Allow access to put/get/delete.
        functions.database.put = proc (
            key: string, val: string
        ) {.forceCheck: [
            DBWriteError
        ].} =
            try:
                db.put(key, val)
            except Exception as e:
                raise newException(DBWriteError, e.msg)

        functions.database.get = proc (
            key: string
        ): string {.forceCheck: [
            DBReadError
        ].} =
            try:
                result = db.get(key)
            except Exception as e:
                raise newException(DBReadError, e.msg)

        functions.database.delete = proc (
            key: string
        ) {.forceCheck: [
            DBWriteError
        ].} =
            try:
                db.delete(key)
            except Exception as e:
                raise newException(DBWriteError, e.msg)
