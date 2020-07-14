import Errors, Hash

type Merkle* = object
  data: seq[seq[Hash[256]]]

func hash*(
  merkle: Merkle
): Hash[256] {.forceCheck: [].} =
  if merkle.data.len != 0:
    result = merkle.data[^1][0]

proc rehash*(
  merkle: var Merkle,
  rowIndex: int,
  pairIndex: int,
  recurse: bool = true
) {.forceCheck: [].} =
  if merkle.data[rowIndex].len == 1:
    return

  var
    first: Hash[256] = merkle.data[rowIndex][pairIndex]
    second: Hash[256] = first
  if high(merkle.data[rowIndex]) != pairIndex:
    second = merkle.data[rowIndex][pairIndex + 1]
  var next: Hash[256] = Blake256(first.serialize() & second.serialize())

  if rowIndex == high(merkle.data):
    merkle.data.add(@[])

  var nextIndex: int = pairIndex div 2
  if nextIndex == merkle.data[rowIndex + 1].len:
    merkle.data[rowIndex + 1].setLen(nextIndex + 1)
  merkle.data[rowIndex + 1][pairIndex div 2] = next

  if recurse:
    merkle.rehash(rowIndex + 1, (pairIndex div 4) * 2)

template leafToPairIndex(
  leaf: int
): int =
  leaf and (not 0b1)

proc add*(
  merkle: var Merkle,
  value: Hash[256]
) {.forceCheck: [].} =
  if merkle.data.len == 0:
    merkle.data = @[@[value]]
    return

  merkle.data[0].add(value)
  merkle.rehash(0, leafToPairIndex(high(merkle.data[0])))

proc newMerkle*(
  hashes: varargs[Hash[256]]
): Merkle {.forceCheck: [].} =
  if hashes.len == 0:
    return

  result.data = @[@hashes]
  var r: int = 0
  while r < result.data.len:
    for p in countup(0, leafToPairIndex(high(result.data[r])), 2):
      result.rehash(r, p, false)
    inc(r)
