# Usage

Meros RPC's is fully compliant with the JSON-RPC 2.0 standard, and is available on port 5133 by default. Calls are POSTed to the node.

Meros sorts calls into the following modules:
- `system`
- `personal`
- `merit`
- `lattice`
- `network`

The JSON-RPC 2.0 `method` field is constructed via prefixing each RPC method with its module's name plus an underscore, as so: `module_method`. Every JSON-RPC 2.0 `params` is an array.

Bytes will always be sent, and expected, in hexadecimal notation.
