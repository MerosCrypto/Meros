# Usage

Meros RPC's is fully compliant with the JSON-RPC 2.0 standard, and is available on port 5133 by default. Calls are sent to the node via TCP.

Meros sorts calls into the following modules:
- `system`
- `personal`
- `merit`
- `transactions`
- `network`

The JSON-RPC 2.0 `method` field is constructed via prefixing each RPC method with its module's name plus an underscore, as so: `module_method`. Every JSON-RPC 2.0 `params` is an array. In order to specify an optional argument after an argument you want to omit, supply the default value for that argument. Bytes are sent, and received, in hexadecimal notation.
