#Errors lib.
import ../../lib/Errors

#RocksDB wrapper.
import rocksdb

#DB object.
type DB = ref object of RootObj
    #Path.
    path: string
    #DB options.
    options: rocksdb_options_t
    #Write options.
    write: rocksdb_writeoptions_t
    #Read options.
    read: rocksdb_readoptions_t
    #DB.
    db: rocksdb_t

#Construcor.
proc newDB*(path: string): DB {.raises: [MemoryError].} =
    result = DB(
        path: path,
        options: rocksdb_options_create(),
        write: rocksdb_writeoptions_create(),
        read: rocksdb_readoptions_create(),
    )
    #Open the DB.
    var err: cstring
    result.db = rocksdb_open(result.options, path, addr err)
    #TODO: HANDLE ERROR.

    #Deallocate the error.
    try:
        dealloc(err)
    except:
        raise newException(MemoryError, "Couldn't deallocate an error string from RocksDB.")

#Write a key/value to the DB.
proc write*(db: DB, key: string, value: string) {.raises: [MemoryError].} =
    #Error var.
    var err: cstring
    #Write the key/value pair.
    rocksdb_put(db.db, db.write, key, key.len, value, value.len, addr err)
    #TODO: HANDLE ERROR.

    #Deallocate the error.
    try:
        dealloc(err)
    except:
        raise newException(MemoryError, "Couldn't deallocate an error string from RocksDB.")

#Read a key/value pair from the DB.
proc read*(db: DB, key: string): string {.raises: [MemoryError].} =
    var
        #Error var.
        err: cstring
        #Data length.
        len: int
        #RocksDB doesn't return a null terminator.
        unterminated: cstring = rocksdb_get(db.db, db.read, key, key.len, addr len, addr err)
    #HANDLE ERROR.

    #Deallocate the error.
    try:
        dealloc(err)
    except:
        raise newException(MemoryError, "Couldn't deallocate an error string from RocksDB.")

    #Create a string of the same length.
    result = newString(len)
    #Copy the memory in.
    copyMem(addr result[0], addr unterminated[0], len * sizeof(char))

#Close the DB.
proc close*(db: DB) {.raises: [].} =
    #Destroy all of the options.
    rocksdb_writeoptions_destroy(db.write)
    rocksdb_readoptions_destroy(db.read)
    rocksdb_options_destroy(db.options)

    #Close the DB itself.
    rocksdb_close(db.db)
