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

proc runner2(name: string) {.cps:MyCont.}=
  var i = 0
  while i < 4:
    inc i
    echo name, " ", i
    schedule()
  echo ""

proc push(work: Work, c: MyCont) =
  work.queue.addLast c
  c.work = work

proc run(work: Work) =
  while work.queue.len > 0:
    var c = work.queue.popFirst()
    while c.running:
      c = c.fn(c)

var mywork = Work()
mywork.push whelp runner2("donkey")
mywork.push whelp runner2("tiger")
mywork.run()
