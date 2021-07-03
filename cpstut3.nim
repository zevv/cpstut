
# Growing your own continuations

import cps
import deques

type

  Work = ref object
    queue: Deque[Continuation]

  MyCont = ref object of Continuation
    work: Work

proc schedule(c: MyCont): MyCont {.cpsMagic.} =
  c.work.queue.addLast c
  return nil

proc push(work: Work, c: MyCont) =
  work.queue.addLast c
  c.work = work

proc work(work: Work) =
  while work.queue.len > 0:
    var c = work.queue.popFirst()
    while c.running:
      c = c.fn(c)

proc runner(name: string) {.cps:MyCont.}=
  var i = 0
  while i < 4:
    inc i
    echo name, " ", i
    schedule()
  echo ""

var mywork = Work()
mywork.push whelp runner("donkey")
mywork.push whelp runner("tiger")
mywork.work()
