"""
#Types.
from typing import Dict, Any

#Consensus classes.
from PythonTests.Classes.Consensus.MeritRemoval import MeritRemoval

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#RPC class.
from PythonTests.Meros.RPC import RPC

#Verify a MeritRemoval.
def verifyMeritRemoval(
    rpc: RPC,
    height: int,
    merit: int,
    removal: MeritRemoval,
    pending: bool
) -> None:
    #Verify the Merit Holder height.
    if rpc.call("consensus", "getHeight", [removal.holder.hex()]) != height:
        raise TestError("Merit Holder height doesn't match.")

    #Get the MeritRemoval.
    mrJSON: Dict[str, Any] = rpc.call(
        "consensus",
        "getElement",
        [removal.holder.hex(), removal.nonce]
    )

    #Verify the nonce.
    if pending:
        if mrJSON["nonce"] != 0:
            raise TestError("MeritRemoval nonce is invalid.")
        mrJSON["nonce"] = removal.nonce

    #Verify the MeritRemoval.
    if mrJSON != removal.toJSON():
        raise TestError("Merit Removal doesn't match.")

    #Verify the Total Merit.
    if rpc.call("merit", "getTotalMerit") != merit if pending else 0:
        raise TestError("Total Merit doesn't match.")

    #Verify the Unlocked Merit.
    if rpc.call("merit", "getUnlockedMerit", [removal.holder.hex()]) != merit if pending else 0:
        raise TestError("Unlocked Merit doesn't match.")

    #Verify the Merit Holder's Merit.
    if rpc.call("merit", "getMerit", [removal.holder.hex()]) != {
        "unlocked": True,
        "malicious": pending,
        "merit": merit if pending else 0
    }:
        raise TestError("Merit Holder's Merit doesn't match.")
"""
