import ../../../lib/Errors

import objects/DBObj
export DBObj

import TransactionsDB, ConsensusDB, MeritDB

proc commit*(
  db: DB,
  height: int
) {.forceCheck: [].} =
  TransactionsDB.commit(db)
  ConsensusDB.commit(db)
  MeritDB.commit(db, height)
