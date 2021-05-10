#Tests handling of erroneous values for hex/Hash/BLSPublicKey/EdPublicKey.
#Address is tested in the AddressTest.

import e2e.Libs.Ristretto.Ristretto as Ristretto

from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Transactions.Data import Data

from e2e.Meros.RPC import RPC
from e2e.Tests.Errors import TestError

#pylint: disable=too-many-statements
def StringBasedTypesTest(
  rpc: RPC
) -> None:
  edPrivKey: Ristretto.SigningKey = Ristretto.SigningKey(b'\0' * 32)
  edPubKey: bytes = edPrivKey.get_verifying_key()
  blsPubKey: PublicKey = PrivateKey(0).toPublicKey()

  #hex.
  #Test 0x-prefixed and no-0x both work without issue.
  data: Data = Data(bytes(32), edPubKey)
  data.sign(edPrivKey)
  rpc.call("transactions", "publishTransactionWithoutWork", {"type": "Data", "transaction": "0x" + data.serialize()[:-4].hex()})

  data = Data(data.hash, b"abc")
  data.sign(edPrivKey)
  rpc.call("transactions", "publishTransactionWithoutWork", {"type": "Data", "transaction": data.serialize()[:-4].hex()})

  #Test non-hex data is properly handled.
  try:
    rpc.call("transactions", "publishTransactionWithoutWork", {"type": "Data", "transaction": "az"})
    raise TestError()
  except Exception as e:
    if str(e) != "-32602 Invalid params.":
      raise TestError("Meros accepted non-hex data for a hex argument.")

  #Hash.
  rpc.call("transactions", "getTransaction", {"hash": data.hash.hex()})
  rpc.call("transactions", "getTransaction", {"hash": "0x" + data.hash.hex()})

  #Also call the upper form, supplementing the above hex tests (as Hash routes through hex).
  rpc.call("transactions", "getTransaction", {"hash": data.hash.hex().upper()})
  rpc.call("transactions", "getTransaction", {"hash": "0x" + data.hash.hex().upper()})

  #Improper length.
  try:
    rpc.call("transactions", "getTransaction", {"hash": data.hash.hex().upper()[:-2]})
    raise TestError()
  except Exception as e:
    if str(e) != "-32602 Invalid params.":
      raise TestError("Meros accepted a hex string with an improper length as a Hash.")

  #BLSPublicKey.
  try:
    rpc.call("merit", "getNickname", {"key": blsPubKey.serialize().hex()})
    raise TestError()
  except Exception as e:
    if str(e) != "-2 Key doesn't have a nickname assigned.":
      raise TestError("Meros didn't accept a valid BLSPublicKey.")
  try:
    rpc.call("merit", "getNickname", {"key": blsPubKey.serialize().hex()[:-2]})
    raise TestError()
  except Exception as e:
    if str(e) != "-32602 Invalid params.":
      raise TestError("Meros accepted a hex string with an improper length as a BLSPublicKey.")

  #Missing flags.
  try:
    rpc.call("merit", "getNickname", {"key": "0" + blsPubKey.serialize().hex()[1]})
    raise TestError()
  except Exception as e:
    if str(e) != "-32602 Invalid params.":
      raise TestError("Meros accepted an invalid BLSPublicKey as a BLSPublicKey.")

  #EdPublicKey.
  rpc.call("personal", "setAccount", {"key": edPubKey.hex(), "chainCode": bytes(32).hex()})
  try:
    rpc.call("personal", "setAccount", {"key": edPubKey[:-2].hex(), "chainCode": bytes(32).hex()})
    raise TestError()
  except Exception as e:
    if str(e) != "-32602 Invalid params.":
      raise TestError("Meros accepted a hex string with an improper length as an EdPublicKey.")
