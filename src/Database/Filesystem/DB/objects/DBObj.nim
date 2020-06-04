import sets, tables

import mc_lmdb
export put, get, delete

import ../../../../lib/[Errors, Hash]

type
  TransactionsDB* = ref object
    cache*: Table[string, string]
    deleted*: HashSet[string]
    unmentioned*: HashSet[Hash[256]]

  ConsensusDB* = ref object
    cache*: Table[string, string]
    deleted*: HashSet[string]
    malicious*: set[uint16]
    unmentioned*: HashSet[Hash[256]]

  MeritDB* = ref object
    cache*: Table[string, string]
    deleted*: HashSet[string]
    removals*: Table[uint16, int]
    when defined(merosTests):
      used*: HashSet[string]

  DB* = ref object
    lmdb*: LMDB
    transactions*: TransactionsDB
    consensus*: ConsensusDB
    merit*: MeritDB

proc newTransactionsDB(): TransactionsDB {.inline, forceCheck: [].} =
  TransactionsDB(
    cache: initTable[string, string](),
    deleted: initHashSet[string](),
    unmentioned: initHashSet[Hash[256]]()
  )

proc newConsensusDB(): ConsensusDB {.inline, forceCheck: [].} =
  ConsensusDB(
    cache: initTable[string, string](),
    deleted: initHashSet[string](),
    malicious: {},
    unmentioned: initHashSet[Hash[256]]()
  )

proc newMeritDB(): MeritDB {.inline, forceCheck: [].} =
  when not defined(merosTests):
    MeritDB(
      cache: initTable[string, string](),
      deleted: initHashSet[string](),
      removals: initTable[uint16, int]()
    )
  else:
    MeritDB(
      cache: initTable[string, string](),
      deleted: initHashSet[string](),
      removals: initTable[uint16, int](),
      used: initHashSet[string]()
    )

proc newDB*(
  path: string,
  size: int64
): DB {.forceCheck: [
  DBError
].} =
  try:
    result = DB(
      lmdb: newLMDB(path, size, 3),
      transactions: newTransactionsDB(),
      consensus: newConsensusDB(),
      merit: newMeritDB()
    )
    result.lmdb.open("transactions")
    result.lmdb.open("consensus")
    result.lmdb.open("merit")
  except Exception as e:
    raise newLoggedException(DBError, "Couldn't open the DB: " & e.msg)

proc close*(
  db: DB
) {.forceCheck: [
  DBError
].} =
  try:
    db.lmdb.close()
  except Exception as e:
    raise newLoggedException(DBError, "Couldn't close the DB: " & e.msg)
