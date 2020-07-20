from typing import List, Any
from importlib import import_module

from multiprocessing import Process, Manager
from os import listdir, path

#pylint: disable=unused-import
#Required until we move every generator to PrototypeChain.
import e2e.Vectors.Generation.Merit.BlankBlocks

folderQueue: List[List[str]] = [["e2e", "Vectors", "Generation"]]
generators: List[str] = []

while folderQueue:
  currFolder: List[str] = folderQueue.pop()
  for entry in listdir(path.join(*currFolder)):
    if entry in {
      "Generate.py",
      "BlankBlocks.py",
      "__pycache__"
    }:
      continue

    if path.isfile(path.join(*currFolder, entry)):
      if entry[-3:] != ".py":
        continue
      generators.append(".".join(currFolder + [entry[:-3]]))
    else:
      folderQueue.append(currFolder + [entry])

def runGenerator(
  generatorsProxy: Any
) -> None:
  while generatorsProxy:
    import_module(generatorsProxy.pop())

with Manager() as manager:
  mpGenerators: Any = manager.list(generators)

  processes: List[Process] = []
  for _ in range(4):
    processes.append(Process(target=runGenerator, args=[mpGenerators]))
    processes[-1].start()

  for process in processes:
    process.join()
