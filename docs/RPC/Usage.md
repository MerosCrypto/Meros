# Usage

The default Meros RPC port is 5133. Requests are sent as JSON with a new line after them. Requests are NOT HTTP POST requests.

Every request has three fields.
- `module`, a string of the name of the RPC module you're trying to access There's `system`, `personal`, `merit`, `lattice`, and `network`.
- `method`, a string of the method you're calling. To see what methods are available, please see the docs for each individual module.
- `args`, an array of the arguments you're passing to the method.

Every call will have a response. If the call doesn't return anything, the response will contain a `success` boolean, with a value of true. If the call failed, the response will have a `error` field. That said, `system.quit` will always respond with an empty object.

Bytes will always be sent via their hex representation.
