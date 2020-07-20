#pylint: disable=invalid-name

from typing import Any
from pathlib import Path
import shutil

from filelock import FileLock
from pytest import fixture

from e2e.Meros.Meros import Meros
from e2e.Meros.RPC import RPC

#Delete the existing data directory.
@fixture(scope="session", params=["./data/e2e"])
def dataDir(
  request: Any,
  tmp_path_factory: Any,
  worker_id: str
) -> str:
  #Get the temp directory shared by all workers.
  tmpDir: Path = tmp_path_factory.getbasetemp().parent
  fn: Path = tmpDir / ".clean"
  try:
    if worker_id == "master":
      shutil.rmtree(request.param)
    else:
      with FileLock(str(fn) + ".lock"):
        if not fn.is_file():
          shutil.rmtree(request.param)
          fn.write_text("")
  except FileNotFoundError:
    pass
  return request.param

@fixture(scope="module", params=[5132])
def meros(
  #pylint: disable=redefined-outer-name
  dataDir: str,
  request: Any,
  worker_id: str
) -> Meros:
  #If xdist is disabled, the worker_id will return "master" and
  #"gw1", "gw2", ... otherwise
  index: int = 0
  if worker_id.startswith("gw"):
    index = int(worker_id[2:])
  result: Meros = Meros(
    request.node.module.__name__,
    request.param + (2 * index),
    request.param + (2 * index) + 1,
    dataDir
  )
  request.addfinalizer(result.quit)
  return result

@fixture(scope="module")
def rpc(
  #pylint: disable=redefined-outer-name
  meros: Meros,
  request: Any
) -> RPC:
  result: RPC = RPC(meros)
  request.addfinalizer(result.quit)
  return result
