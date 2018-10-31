# Usage

The default Ember RPC port is 5333. Requests are sent as JSON, and are sent with a new line after them. Requests are NOT HTTP POST requests.

Every request has three fields.
- `module`, a string of the name of the RPC module you're trying to access There's `system`, `personal`, `merit`, `lattice`, and `network`.
- `method`, a string of the method you're calling. To see what methods are available, please see the docs for each individual module.
- `args`, an array of the arguments you're passing to the method.

Every call will have a response. If the call failed, the response will have a `error` field. The only call which doesn't report if it failed is `system.quit`.
