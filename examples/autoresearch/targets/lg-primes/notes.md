# Notes for the researcher (the human edits this file)

`solve.lg` is **let-go**, a Clojure dialect on a Go runtime. It is not JVM Clojure:

- No Java interop: `Math/sqrt`, `(int-array n)`, `aset`, `.method` calls do not exist.
- Math lives in a namespace: `(:require [math :as math])`, then `math/sqrt`,
  `math/floor`, `math/pow`. `quot`, `rem`, `mod`, `inc`, `dec` are core.
- Core sequence functions, `loop`/`recur`, `reduce`, vectors, sets, maps,
  `transient`/`persistent!`/`assoc!`/`conj!`, and atoms are available.
- Integer square root without floats: loop while `(<= (* d d) n)`.
- A compile error is a crash: prefer constructs you are sure exist.
