from typing import List

from random import getrandbits
from threading import Thread

from e2e.Libs.RandomX import setRandomXKey, RandomX

from e2e.Tests.Errors import TestError

def RandomXTest() -> None:
  #Generate 100 RandomX keys, and create 10 hashes with each.
  #As this is single threaded, it's guaranteed to be safe.
  keys: List[bytes] = []
  hashed: List[List[bytes]] = []
  hashes: List[List[bytes]] = []
  for _ in range(100):
    keys.append(bytes(getrandbits(8) for _ in range(32)))
    setRandomXKey(keys[-1])

    hashed.append([])
    hashes.append([])
    for _ in range(10):
      hashed[-1].append(bytes(getrandbits(8) for _ in range(getrandbits(8))))
      hashes[-1].append(RandomX(hashed[-1][-1]))

  def rxThread(
    t: int
  ) -> None:
    for k in range(t * 25, (t + 1) * 25):
      setRandomXKey(keys[k])
      for h in range(len(hashed[k])):
        if RandomX(hashed[k][h]) != hashes[k][h]:
          raise TestError("Threaded RandomX returned a different result than the single-threaded version.")

  #Now, spawn 4 threads and re-iterate over every hash.
  threads: List[Thread] = []
  for t in range(4):
    threads.append(Thread(None, rxThread, "RX-" + str(t), [t]))
    threads[-1].start()
  for thread in threads:
    thread.join()
