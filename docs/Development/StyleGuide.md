# Meros Style Guide

1. Be concise, but never implicit.
2. Use a 4-space ident.
3. Try to remain under 80 characters per line.

4. For `var`/`let`, use pascalCase for naming.
5. For `type` values, use CamelCase.
6. For `const`, use ALL_CAPS, with underscores between words.
7. Use a single `var`/`let`/`type` block when defining things next to each other.
8. Always define the type of your `var`s, `let`s, and `proc` arguments INDIVIDUALLY (don’t group multiple arguments with a single type).
9. Always prefix an `enum` value with it’s `enum` (`Enum.EnumValue`).

10. Use `func` wherever possible, and try to always write pure code.
11. Every function argument, and every Exception, should have their own line.
12. Always throw an Exception on an error, even if you can `return false`, UNLESS the function is named `verify` or `isX`.
13. All functions must be decorated with the `{.forceCheck.}` pragma. For more info, see https://github.com/MerosCrypto/ForceCheck.
14. Comment your code as needed. It is better to comment too much than too little.
