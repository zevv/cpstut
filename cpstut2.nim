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

proc runner2(name: string) {.cps:MyCont.}=
  var i = 0
  while i < 4:
    inc i
    echo name, " ", i
    schedule()
  echo ""

work.addLast whelp runner2("donkey")
work.addLast whelp runner2("tiger")

runwork()
