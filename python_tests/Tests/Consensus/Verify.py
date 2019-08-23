#Types.
from typing import Dict, Any

#Consensus classes.
from python_tests.Classes.Consensus.MeritRemoval import MeritRemoval
from python_tests.Classes.Consensus.Consensus import Consensus

#TestError Exception.
from python_tests.Tests.Errors import TestError

#RPC class.
from python_tests.Meros.RPC import RPC

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
    mrJSON: Dict[str, Any] = rpc.call("consensus", "getElement", [
        removal.holder.hex(),
        removal.nonce
    ])

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

    #Verify the Live Merit.
    if rpc.call("merit", "getLiveMerit", [removal.holder.hex()]) != merit if pending else 0:
        raise TestError("Live Merit doesn't match.")

    #Verify the Merit Holder's Merit.
    if rpc.call("merit", "getMerit", [removal.holder.hex()]) != {
        "live": True,
        "malicious": pending,
        "merit": merit if pending else 0
    }:
        raise TestError("Merit Holder's Merit doesn't match.")

#Verify the Consensus.
def verifyConsensus(
    rpc: RPC,
    consensus: Consensus
) -> None:
    for pubKey in consensus.holders:
        for e in range(len(consensus.holders[pubKey])):
            if rpc.call("consensus", "getElement", [
                pubKey.hex(),
                e
            ]) != consensus.holders[pubKey][e].toJSON():
                raise TestError("Element doesn't match.")
