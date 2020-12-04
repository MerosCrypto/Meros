import sets, tables

import ../../../src/lib/Hash
import ../../../src/Wallet/MinerWallet

import ../../../src/Database/Consensus/Consensus

import ../../Fuzzed

proc compare*(
  e1: Element or VerificationPacket or SignedVerificationPacket or SignedMeritRemoval,
  e2: Element or VerificationPacket or SignedVerificationPacket or SignedMeritRemoval
) =
  check e1 == e2

proc compare*(
  ts1: TransactionStatus,
  ts2: TransactionStatus
) =
  check:
    ts1.epoch == ts2.epoch
    ts1.competing == ts2.competing
    ts1.verified == ts2.verified
    ts1.beaten == ts2.beaten

    symmetricDifference(ts1.holders, ts2.holders).len == 0
    symmetricDifference(ts1.pending, ts2.pending).len == 0

    ts1.signatures.len == ts2.signatures.len
    ts1.merit == ts2.merit

  compare(ts1.packet, ts2.packet)

  for h in ts1.signatures.keys():
    check ts1.signatures[h] == ts2.signatures[h]

proc compare*(
  sf1: SpamFilter,
  sf2: SpamFilter
) =
  check:
    sf1.medianPos == sf2.medianPos
    sf1.left == sf2.left
    sf1.right == sf2.right

    sf1.difficulties.len == sf2.difficulties.len
    sf1.votes.len == sf2.votes.len

    sf1.initialDifficulty == sf2.initialDifficulty
    sf1.difficulty == sf2.difficulty

  for d in 0 ..< sf1.difficulties.len:
    check:
      sf1.difficulties[d].difficulty == sf2.difficulties[d].difficulty
      sf1.difficulties[d].votes == sf2.difficulties[d].votes

  for holder in sf1.votes.keys():
    check sf1.votes[holder].difficulty == sf2.votes[holder].difficulty

proc compare*(
  c1: Consensus,
  c2: Consensus
) =
  compare(c1.filters.send, c2.filters.send)
  compare(c1.filters.data, c2.filters.data)

  check c1.malicious.len == c2.malicious.len
  for nick in c1.malicious.keys():
    var
      c1Malicious: seq[SignedMeritRemoval] = c1.malicious[nick]
      c2Malicious: seq[SignedMeritRemoval] = c2.malicious[nick]

    check c1Malicious.len == c2Malicious.len
    for r1 in 0 ..< c1Malicious.len:
      for r2 in 0 ..< c2Malicious.len:
        if c1Malicious[r1] == c2Malicious[r2]:
          c2Malicious.del(r2)
          break

        if (r2 == c2Malicious.len - 1):
          check false

  check c1.statuses.len == c2.statuses.len
  for hash in c1.statuses.keys():
    compare(c1.statuses[hash], c2.statuses[hash])

  check:
    symmetricDifference(c1.unmentioned, c2.unmentioned).len == 0
    c1.signatures.len == c2.signatures.len
    c1.archived.len == c2.archived.len

  for holder in c1.signatures.keys():
    check c1.signatures[holder].len == c2.signatures[holder].len
    for s in 0 ..< c1.signatures[holder].len:
      check c1.signatures[holder][s] == c2.signatures[holder][s]

  for holder in c1.archived.keys():
    check c1.archived[holder] == c2.archived[holder]
