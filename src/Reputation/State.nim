import ../lib/BN

import Block
import Blockchain

import tables

type StateType* = ref object of RootObj
    state: Table

var state: StateType = StateType(
    state: initTable[string, BN]()
)
echo "Made the state var."

state.state["test"] = newBN("7")
echo "Set test."

echo state.state["test"]
