import random

import ../../src/lib/[Util, Hash, Merkle]

import ../Fuzzed

suite "Merkle":
  noFuzzTest "`nil` Merkle trees.":
    check:
      newMerkle().isLeaf
      newMerkle().hash == "".pad(32).toHash[:256]()

  noFuzzTest "Leaves.":
    check newMerkle("1".pad(32).toHash[:256]()).hash == "1".pad(32).toHash[:256]()

  noFuzzTest "A blank Merkle tree with an added leaf is the same as a tree created with said leaf.":
    var
      created: Merkle = newMerkle("".pad(32).toHash[:256]())
      added: Merkle = newMerkle()

    added.add("".pad(32).toHash[:256]())
    check:
      created.isLeaf
      added.isLeaf
      added.hash == created.hash

  highFuzzTest "Verify.":
    #Create a random amount of hashes.
    var
      hashLen: int = rand(900) + 100
      hashes: seq[Hash[256]] = newSeq[Hash[256]](hashLen)
    for h in 0 ..< hashLen:
      hashes[h] = Blake256(h.toBinary())

    var
      #Copy the hashes so we can form our own tree of it (albeit slowly).
      fullCopy: seq[Hash[256]] = hashes
      #Pick a random sub-amount for use in a Merkle tree created with both the constructor and addition.
      #The +1 is to make sure we don't skip the both test.
      bothLen: int = rand(hashLen - 2) + 1
      #Create a second copy of the hashes with this smaller range.
      partialCopy: seq[Hash[256]] = hashes[0 ..< bothLen]
      #Define three trees. One of newMerkle, one of addition, and one of both.
      constructor: Merkle = newMerkle(hashes)
      addition: Merkle = newMerkle()
      both: Merkle = newMerkle(hashes[0 ..< bothLen])

    #Create the addition tree.
    for hash in hashes:
      addition.add(hash)

    #Generate our own tree, slowly, using fullCopy.
    #Run until we only have one hash.
    while fullCopy.len != 1:
      #Iterate over the seq by a 2 count.
      for h in countup(0, fullCopy.len - 1, 2):
        #If there is no h + 1, add the last hash again.
        if fullCopy.len mod 2 == 1:
          fullCopy.add(fullCopy[fullCopy.len - 1])

        #Turn fullCopy[h] into the branch hash for fullCopy[h .. h + 1].
        fullCopy[h] = Blake256(fullCopy[h].serialize() & fullCopy[h + 1].serialize())

      #Delete every other element.
      var d: int = 1
      while d < fullCopy.len:
        fullCopy.delete(d)
        inc(d)

    #Generate our own tree, slowly, using partialCopy.
    while partialCopy.len != 1:
      for h in countup(0, partialCopy.len - 1, 2):
        if partialCopy.len mod 2 == 1:
          partialCopy.add(partialCopy[partialCopy.len - 1])

        partialCopy[h] = Blake256(partialCopy[h].serialize() & partialCopy[h + 1].serialize())

      var d: int = 1
      while d < partialCopy.len:
        partialCopy.delete(d)
        inc(d)

    check:
      #Test that the constructor and addition tree have the same hash as fullCopy.
      constructor.hash == fullCopy[0]
      addition.hash == fullCopy[0]
      #Test that the both tree has the same hash as partialCopy.
      both.hash == partialCopy[0]

    #Complete the both tree.
    for hash in hashes[bothLen ..< hashLen]:
      both.add(hash)

    #Test that the both tree and the fullCopy have the same hash.
    check both.hash == fullCopy[0]
