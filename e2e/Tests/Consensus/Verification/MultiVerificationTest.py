#Tests that blocks can't have multiple verification packets for the same transaction.
from time import time, sleep
from typing import Any, Dict, List

import ed25519

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Transactions import Data, Transactions
from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Merit.Merit import Merit

from e2e.Meros.RPC import RPC
from e2e.Meros.Meros import MessageType

from e2e.Tests.Errors import TestError

def MultiVerificationTest(
  rpc: RPC
) -> None:
  transactions: Transactions = Transactions()
  blocks: List[Dict[str, Any]] = []
  merit: Merit = Merit()
  #TODO