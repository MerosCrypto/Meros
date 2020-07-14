import random
import algorithm
import sequtils
import tables

import ../../../src/lib/Util

import ../../../src/Database/Merit/objects/StateObj
import ../../../src/Database/Consensus/objects/SpamFilterObj

import ../../Fuzzed

const
  INITIAL_DIFFICULTY: uint32 = uint32(3)
  OTHER_DIFFICULTY: uint32 = uint32(5)

#Recreate the VotedDifficulty object for testing purposes.
type VotedDifficultyTest = object
  difficulty: uint32
  holders: seq[uint16]

suite "SpamFilter":
  setup:
    var
      #Holder -> Merit.
      merit: seq[int]
      #List of Difficulties in play, along with their summed votes.
      difficulties: seq[VotedDifficultyTest] = @[]
      filter: SpamFilter = newSpamFilterObj(INITIAL_DIFFICULTY)

  noFuzzTest "Verify the initial difficulty is correct.":
    check filter.difficulty == INITIAL_DIFFICULTY

  noFuzzTest "Verify adding 0 votes doesn't change the initial difficulty.":
    filter.update(
      State(
        merit: @[49],
        statuses: @[MeritStatus.Unlocked]
      ),
      0,
      OTHER_DIFFICULTY
    )
    check filter.difficulty == INITIAL_DIFFICULTY

  noFuzzTest "Add 1 vote and remove it via a decrement.":
    filter.update(
      State(
        merit: @[50],
        statuses: @[MeritStatus.Unlocked]
      ),
      0,
      OTHER_DIFFICULTY
    )
    check filter.difficulty == OTHER_DIFFICULTY
    filter.handleBlock(
      State(
        merit: @[49, 1],
        statuses: @[MeritStatus.Unlocked, MeritStatus.Unlocked]
      ),
      StateChanges(
        incd: 1,
        decd: 0
      ),
      initTable[uint16, uint32]()
    )
    check:
      filter.difficulty == INITIAL_DIFFICULTY
      filter.left == 0
      filter.right == 0
      filter.medianPos == -1

  noFuzzTest "Add 1 vote and remove it via a MeritRemoval.":
    filter.update(
      State(
        merit: @[50],
        statuses: @[MeritStatus.Unlocked]
      ),
      0,
      OTHER_DIFFICULTY
    )
    check filter.difficulty == OTHER_DIFFICULTY
    filter.remove(0, 50)
    check:
      filter.difficulty == INITIAL_DIFFICULTY
      filter.left == 0
      filter.right == 0
      filter.medianPos == -1

  highFuzzTest "Verify.":
    #Create a random amount of holders.
    for h in 0 ..< rand(50) + 2:
      merit.add(0)

    var fauxStatuses: seq[MeritStatus] = @[]
    for _ in 0 ..< merit.len:
      fauxStatuses.add(MeritStatus.Unlocked)

    #Iterate over 10000 actions.
    for a in 0 ..< 10000:
      #Update a holder's vote.
      #Try a maximum of three times to find a holder with at least 50 Merit.
      for i in 0 ..< 3:
        var
          holder: uint16 = uint16(rand(merit.len - 1))
          difficulty: uint32
        if merit[int(holder)] < 50:
          continue

        #Remove the holder from the existing difficulty.
        #Also remove holders/difficulties which no longer have votes.
        var
          d: int = 0
          h: int
          diffVotes: int
        while d < difficulties.len:
          h = 0
          diffVotes = 0
          while h < difficulties[d].holders.len:
            if difficulties[d].holders[h] == holder:
              difficulties[d].holders.del(h)
              continue

            if merit[int(difficulties[d].holders[h])] div 50 == 0:
              difficulties[d].holders.del(h)
              continue

            diffVotes += merit[int(difficulties[d].holders[h])] div 50
            inc(h)

          if diffVotes == 0:
            difficulties.del(d)
            continue
          inc(d)

        #Select an existing difficulty.
        if (difficulties.len != 0) and (rand(2) == 0):
          var d: int = rand(high(difficulties))
          difficulty = difficulties[d].difficulty

          #Add this holder to the difficulty.
          difficulties[d].holders.add(holder)
          difficulties[d].holders = difficulties[d].holders.deduplicate()

        #Select a new difficulty.
        else:
          var found: bool = true
          while found:
            difficulty = uint32(rand(high(int32)))

            #Break if no existing difficulty is the same.
            found = false
            for diff in difficulties:
              if difficulty == diff.difficulty:
                found = true
                break

          #Add the difficulty to difficulties.
          difficulties.add(VotedDifficultyTest(
            difficulty: difficulty,
            holders: @[uint16(holder)]
          ))

        #Update the difficulty.
        filter.update(
          State(
            merit: merit,
            statuses: fauxStatuses
          ),
          holder,
          difficulty
        )
        break

      #Increment a holder's Merit.
      if a < 5000:
        var incd: uint16 = uint16(rand(merit.len - 1))
        merit[int(incd)] += 1

        filter.handleBlock(
          State(
            merit: merit,
            statuses: fauxStatuses
          ),
          StateChanges(
            incd: incd,
            decd: -1
          ),
          initTable[uint16, uint32]()
        )

      #Increment and decrement holders' Merit.
      else:
        var
          incd: uint16 = uint16(rand(merit.len - 1))
          decd: int = rand(merit.len - 1)
        while merit[decd] == 0:
          decd = rand(merit.len - 1)
        merit[int(incd)] += 1
        merit[decd] -= 1

        filter.handleBlock(
          State(
            merit: merit,
            statuses: fauxStatuses
          ),
          StateChanges(
            incd: incd,
            decd: decd
          ),
          initTable[uint16, uint32]()
        )

        #Remove holders/difficulties which no longer have votes.
        var
          d: int = 0
          h: int
          diffVotes: int
        while d < difficulties.len:
          h = 0
          diffVotes = 0
          while h < difficulties[d].holders.len:
            if merit[int(difficulties[d].holders[h])] div 50 == 0:
              difficulties[d].holders.del(h)
              continue

            diffVotes += merit[int(difficulties[d].holders[h])] div 50
            inc(h)

          if diffVotes == 0:
            difficulties.del(d)
            continue
          inc(d)

      #Remove Merit from a holder.
      if rand(1000) == 0:
        var holder: uint16 = uint16(rand(merit.len - 1))
        filter.remove(holder, merit[int(holder)])
        merit[int(holder)] = 0

        block removeHolder:
          var
            d: int = 0
            h: int
          while d < difficulties.len:
            h = 0
            while h < difficulties[d].holders.len:
              if difficulties[d].holders[h] == holder:
                if difficulties[d].holders.len == 1:
                  difficulties.del(d)
                else:
                  difficulties[d].holders.del(h)
                break removeHolder
              inc(h)
            inc(d)

      #Handle no votes.
      if difficulties.len == 0:
        check filter.difficulty == INITIAL_DIFFICULTY
        continue

      #Sort difficulties.
      difficulties.sort(
        proc (
          x: VotedDifficultyTest,
          y: VotedDifficultyTest
        ): int =
          check x.difficulty != y.difficulty
          if x.difficulty > y.difficulty:
            return 1
          else:
            return -1
      )

      #Turn weighted difficulties into a seq.
      var unweighted: seq[uint32] = @[]
      for d in 0 ..< difficulties.len:
        var sum: int = 0
        for h in difficulties[d].holders:
          sum += merit[int(h)] div 50

        for _ in 0 ..< sum:
          unweighted.add(difficulties[d].difficulty)

      #Verify the median.
      check filter.difficulty == unweighted[unweighted.len div 2]

      #Verify no difficulties have 0 votes.
      for diff in filter.difficulties:
        check diff.votes != 0
