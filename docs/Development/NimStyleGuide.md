# Nim Style Guide

1. Be concise, but never implicit.
2. Use a 2-space ident.

3. For `var`/`let`, use camelCase for naming.
4. For `type` values, use PascalCase.
5. For `const`, use ALL_CAPS, with underscores between words.
6. Use a single `var`/`let`/`type` block when defining things next to each other.
7. Always define the type of your `var`s, `let`s, and `proc` arguments INDIVIDUALLY (don’t group multiple arguments with a single type).
8. Always prefix an `enum` value with it’s `enum` (`Enum.EnumValue`).

9. Use `func` wherever possible, and try to always write pure code.
10. Every function argument, and every Exception, should have their own line.
11. Always throw an Exception on an error, even if you can `return false`, UNLESS the function is named `verify` or `isX`.
12. All functions must be decorated with the `{.forceCheck.}` pragma. For more info, see https://github.com/MerosCrypto/ForceCheck.
13. Comment your code as needed. It is better to comment too much than too little.
