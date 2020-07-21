import ../../../lib/Errors

import objects/DBObj
export DBObj

import TransactionsDB, ConsensusDB, MeritDB

proc commit*(
  db: DB,
  height: int
) {.forceCheck: [].} =
  try:
    var tx: LMDBTransaction = db.lmdb.newTransaction()
    TransactionsDB.commit(db, tx)
    ConsensusDB.commit(db, tx)
    MeritDB.commit(db, tx, height)
    tx.commit()
  except DBError as e:
    panic("Failed to commit a Transaction to LMDB: " & e.msg)
