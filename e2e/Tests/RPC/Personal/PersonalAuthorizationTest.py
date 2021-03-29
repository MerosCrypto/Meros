from e2e.Meros.RPC import RPC
from e2e.Tests.Errors import TestError

def PersonalAuthorizationTest(
  rpc: RPC
) -> None:
  #Test all these methods require authorization.
  #Doesn't test personal_data as that's not officially part of this test; just in it as a side note on key usage.
  #The actual personal_data test should handle that check.
  for method in [
    "setWallet",
    #TODO "setAccountKey",
    "getMnemonic",
    "getMeritHolderKey",
    "getMeritHolderNick",
    "getAccountKey",
    "getAddress",
    #TODO "send",
    #TODO "data",
    #TODO "getUTXOs",
    #TODO "getTransactionTemplate"
  ]:
    try:
      rpc.call("personal", method, auth=False)
      raise Exception()
    except Exception as e:
      if str(e) != "HTTP status isn't 200: 401":
        raise TestError("Could call personal method without authorization.")
