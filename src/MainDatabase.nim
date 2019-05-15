include MainGlobals

proc mainDatabase() {.forceCheck: [].} =
    {.gcsafe.}:
        #Open the database.
        try:
            db = newDB(config.dataDir / config.db, MAX_DB_SIZE)
        except Exception as e:
            doAssert(false, "Couldn't open the DB: " & e.msg)

        var version: int = DB_VERSION
        try:
            version = db.get("version").fromBinary()
        #If this fails because this is a brand new DB, save the current version.
        except Exception:
            try:
                db.put("version", DB_VERSION.toBinary())
            except Exception as e:
                doAssert(false, "Couldn't save the DB version: " & e.msg)

        #Allow access to put/get/delete.
        functions.database.put = proc (
            key: string,
            val: string
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
