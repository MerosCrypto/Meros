include MainChainParams

proc mainDatabase(
  params: ChainParams,
  config: Config,
  database: var DB,
  wallet: var WalletDB
) {.forceCheck: [].} =
  #Open the database.
  try:
    database = newDB(config.dataDir / (config.network & "-" & config.db), MAX_DB_SIZE)
  except DBError as e:
    panic("Couldn't create the DB: " & e.msg)

  var version: int = DB_VERSION
  try:
    version = database.lmdb.get("merit", "version").fromBinary()
  #If this fails because this is a brand new DB, save the current version.
  except Exception:
    try:
      var tx: LMDBTransaction = database.lmdb.newTransaction()
      database.lmdb.put(tx, "merit", "version", DB_VERSION.toBinary())
      tx.commit()
    except Exception as e:
      panic("Couldn't save the DB version: " & e.msg)

  #Confirm the version.
  if version != DB_VERSION:
    panic("DB has a different version.")

  #Open the Wallet Database.
  try:
    wallet = newWalletDB(
      params.GENESIS.pad(32).toHash[:256](),
      config.dataDir / (config.network & "-" & config.db & "-wallet"),
      MAX_DB_SIZE
    )
  except DBError as e:
    panic("Couldn't create the DB: " & e.msg)
