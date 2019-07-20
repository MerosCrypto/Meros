# pyright: strict

#Types.
from typing import Dict, Any

#Transactions classes.
from python_tests.Classes.Transactions.SpamFilter import SpamFilter
from python_tests.Classes.Transactions.Data import Data

#RPC class.
from python_tests.Meros.RPC import RPC

#Ed25519 lib.
import ed25519

pubKey = bytes.fromhex("81F27A00BBFFE6A64E0B33245FDA67A54E86088595691D039FB791C09C3CBBBA")
privKey = bytes.fromhex("610EB27209471207A39EEDC72D46F55D212D1C854610166F44857A8CD9F1D0DA") + pubKey

def DataTest(
    rpc: RPC
) -> None:
    #Create the Spam Filter.
    filter: SpamFilter = SpamFilter(
        bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
    )

    #Create the Data.
    data: Data = Data(
        pubKey.rjust(48, b'\0'),
        b"Hello There! General Kenobi."
    )
    data.sign(privKey)
    data.beat(filter)

    #Handshake with the node.
    rpc.meros.connect(
        254,
        254,
        0
    )

    #Send the Data.
    rpc.meros.data(data)

    #Verify the Data.
    dataJSON: Dict[str, Any] = data.toJSON()
    dataJSON["verified"] = False
    if dataJSON != rpc.call("transactions", "getTransaction", [
        data.hash.hex()
    ]):
        raise Exception("Data doesn't match.")
