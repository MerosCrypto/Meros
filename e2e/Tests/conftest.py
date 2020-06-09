import pytest

#Meros class.
from e2e.Meros.Meros import Meros
from e2e.Meros.RPC import RPC

#Sleep standard function.
from time import sleep

#ShUtil standard lib.
import shutil

@pytest.fixture(scope="session", params = ["./data/e2e", ])
def data_dir(
  request
) -> str:
  d = request.param
  # delete the data directory.
  try:
    shutil.rmtree(d)
  except FileNotFoundError:
    pass
  return d

@pytest.fixture(scope="module")
def rpc(
  meros: Meros,
  request
) -> RPC:
  r = RPC(meros)
  request.addfinalizer(r.quit)
  return r

@pytest.fixture(scope="module", params=[5132,])
def meros(
  data_dir: str,
  request
) -> Meros:
  m = Meros(request.node.module.__name__, request.param, request.param + 1, data_dir)
  # let the instance start up
  sleep(3)
  request.addfinalizer(m.quit)
  return m
