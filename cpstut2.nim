
# A more elaborate example: cooperative scheduling

import cps
import deques

type
  MyCont = ref object of Continuation
  
var work: Deque[Continuation]

proc runWork() =
  while work.len > 0:
    var c = work.popFirst()
    while c.running:
      c = c.fn(c)

proc schedule(c: MyCont): MyCont {.cpsMagic.} =
  work.addLast c
  return nil

proc work(name: string) {.cps:MyCont.}=
  var i = 0
  while i < 4:
    inc i
    echo name, " ", i
    schedule()
  echo ""

work.addLast whelp work("donkey")
work.addLast whelp work("tiger")

runwork()
