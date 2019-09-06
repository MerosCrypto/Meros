#Types.
from typing import Dict, List, Tuple, Any

#Transaction and SpamFilter classes.
from PythonTests.Classes.Transactions.Transaction import Transaction
from PythonTests.Classes.Consensus.SpamFilter import SpamFilter

#Ed25519 lib.
import ed25519

#Blake2b standard function.
from hashlib import blake2b

#Send class.
class Send(Transaction):
    #Constructor.
    #Even though this calls serializeInputs/serializeOutputs, it is above those as it provides the class's type hints.
    def __init__(
        self,
        inputs: List[Tuple[bytes, int]],
        outputs: List[Tuple[bytes, int]],
        signature: bytes = bytes(64),
        proof: int = 0
    ) -> None:
        self.inputs: List[Tuple[bytes, int]] = inputs
        self.outputs: List[Tuple[bytes, int]] = outputs
        self.hash = blake2b(b"\2" + self.serializeInputs() + self.serializeOutputs(), digest_size=48).digest()

        self.signature: bytes = signature

        self.proof: int = proof
        self.argon: bytes = SpamFilter.run(self.hash, self.proof)
        self.verified: bool = False

    #Transaction -> Send. Satisifes static typing requirements.
    @staticmethod
    def fromTransaction(
        tx: Transaction
    ) -> Any:
        return tx

    #Sign.
    def sign(
        self,
        privKey: ed25519.SigningKey
    ) -> None:
        self.signature = privKey.sign(b"MEROS" + self.hash)

    #Mine.
    def beat(
        self,
        spamFilter: SpamFilter
    ) -> None:
        result: Tuple[bytes, int] = spamFilter.beat(self.hash)
        self.argon = result[0]
        self.proof = result[1]

    #Serialize Inputs.
    #Separate from serialize as it's called by the constructor.
    def serializeInputs(
        self
    ) -> bytes:
        result: bytes = bytes()
        for txInput in self.inputs:
            result += txInput[0] + txInput[1].to_bytes(1, "big")
        return result

    #Serialize Outputs.
    #Separate from serialize as it's called by the constructor.
    def serializeOutputs(
        self
    ) -> bytes:
        result: bytes = bytes()
        for output in self.outputs:
            result += output[0] + output[1].to_bytes(8, "big")
        return result

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        return (
            len(self.inputs).to_bytes(1, "big") +
            self.serializeInputs() +
            len(self.outputs).to_bytes(1, "big") +
            self.serializeOutputs() +
            self.signature +
            self.proof.to_bytes(4, "big")
        )

    #Send -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "descendant": "Send",
            "inputs": [],
            "outputs": [],
            "hash": self.hash.hex().upper(),

            "signature": self.signature.hex().upper(),
            "proof": self.proof,
            "argon": self.argon.hex().upper()
        }
        for txInput in self.inputs:
            result["inputs"].append({
                "hash": txInput[0].hex().upper(),
                "nonce": txInput[1]
            })
        for output in self.outputs:
            result["outputs"].append({
                "key": output[0].hex().upper(),
                "amount": str(output[1])
            })
        return result

    #Send -> JSON with verified field.
    def toVector(
        self,
    ) -> Dict[str, Any]:
        result = self.toJSON()
        result["verified"] = self.verified
        return result

    #JSON -> Send.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        inputs: List[Tuple[bytes, int]] = []
        outputs: List[Tuple[bytes, int]] = []
        for txInput in json["inputs"]:
            inputs.append((bytes.fromhex(txInput["hash"]), txInput["nonce"]))
        for output in json["outputs"]:
            outputs.append((
                bytes.fromhex(output["key"]),
                int(output["amount"])
            ))

        result: Send = Send(
            inputs,
            outputs,
            bytes.fromhex(json["signature"]),
            json["proof"]
        )
        if json["verified"]:
            result.verified = True
        return result
