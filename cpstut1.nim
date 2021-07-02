import cps
import deques

type
  Cont1 = ref object of Continuation

proc hello() {.cps:Cont1.} =
  echo "Hello, world!"

var c: Continuation = whelp hello()

doAssert c.running()

c = c.fn(c)

doAssert c.finished
