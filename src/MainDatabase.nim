include MainGlobals

proc mainDatabase() {.forceCheck: [].} =
    {.gcsafe.}:
        #Open the database.
        try:
            database = newDB(config.dataDir / config.db, MAX_DB_SIZE)
        except DBerror as e:
            doAssert(false, "Couldn't create the DB: " & e.msg)

        discard """
        var version: int = DB_VERSION
        try:
            version = db.get("version").fromBinary()
        #If this fails because this is a brand new DB, save the current version.
        except DBerror:
            try:
                db.put("version", DB_VERSION.toBinary())
            except DBerror as e:
                doAssert(false, "Couldn't save the DB version: " & e.msg)
        """
