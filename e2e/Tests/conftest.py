#pylint: disable=invalid-name

from typing import Any
from time import sleep
import shutil

from pytest import fixture

from e2e.Meros.Meros import Meros
from e2e.Meros.RPC import RPC

#Delete the existing data directory.
@fixture(scope="session", params=["./data/e2e"])
def dataDir(
  request: Any
) -> str:
  try:
    shutil.rmtree(request.param)
  except FileNotFoundError:
    pass
  return request.param

@fixture(scope="module", params=[5132])
def meros(
  #pylint: disable=redefined-outer-name
  dataDir: str,
  request: Any
) -> Meros:
  result: Meros = Meros(
    request.node.module.__name__,
    request.param,
    request.param + 1,
    dataDir
  )
  #Let the instance start up.
  sleep(5)
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
