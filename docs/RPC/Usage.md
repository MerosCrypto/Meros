# Usage

Meros's RPC is fully compliant with the JSON-RPC 2.0 standard with HTTP POST being used for the transport. The default port for the server is 5133.

Meros sorts calls into the following modules:
- `system`
- `personal`
- `merit`
- `transactions`
- `network`

The JSON-RPC 2.0 `method` field is constructed via prefixing each RPC method with its module's name plus an underscore, such as `module_methodName`. `params` are always an object. Bytes are transmitted as hexadecimal strings, without any prefix. All Meros amounts are represented atomically, without decimal formatting, and transmitted as strings.

`system` and `personal` (as well as select methods elsewhere) require authentication to be used, which is handled via HTTP Bearer Authentication. The token is available in a file named `.token`, under Meros's data directory. This file is generated every time Meros boots up, so repeated access to the filesystem is effectively required. This is to effectively lock certain methods to whoever actually has access to the system, enabling other methods such as `getPeers` to be called by anyone simply wishing to gather data.
