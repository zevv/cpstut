
# INTRODUCTION
# ============
#
# What you are reading is a little tutorial to get started with Nim CPS. It
# helps to first read the general CPS intruction at
# https://github.com/zevv/cpsdoc to get acquinted with the process and
# terminology. 
# 
# This document will introduce the essential parts of the CPS API to get you
# started writing your own CPS programs. It is written in the literate
# programming style, meaning that this is a readable document, but also a
# compilable and working Nim program.
#
# To run this program, call the nim compiler like so:
#
#   nim r --gc:arc csptut
#
# The latest greatest CPS can be found at https://github.com/disruptek/cps
#
# WHAT IS CPS
# ===========
#
# For now I'll just point to the other documentation that is already available:
# please refer to the README of the disruptek/cps repository for a brief intro,
# or read up at https://github.com/zevv/cpsdoc for a more in-depth description
# of the concepts underlying the CPS transformation
#
# cps is available as a regular nim library that you must import before cps is
# available in your program. The module offers a number of macros and
# templates, for details refer to the module documentation at
# https://disruptek.github.io/cps/cps.html
#
# So we start with the import:

import cps

# BABY STEPS: MY FIRST CPS PROGRAM
# ================================
#
# At the heart of CPS lies the `Continuation` type. In our implementation, this
# is just a regular Nim object that is inheritable. This is what the type looks like:
#
# Continuation = ref object of RootObj
#    fn*: proc (c: Continuation): Continuation {.nimcall.}
#    ...
#
# The object has a few more fields which are used for the CPS implementation
# internally, but one of the fields is very important for the users of cps,
# which is `fn`, which is the function pointer that makes CPS continuations
# tick. We'll get back to its use later.
#
# To start with CPS, you would typically define your own object, inherited from
# the cps Continuation type, like so

type
  Cont1 = ref object of Continuation

# At a later time we will add our own fields to the derived Continuation
# objects, but for now we'll start out simple.


# THE CPS TRANSFORM MACRO
# =======================
#
# Next to the continuation type, the cps macro is the other imporant part for
# writing CPS programs, this is the macro that will be applied to any Nim
# functions we want to transform to CPS style. This macro does two jobs: 
#
# - it will split the Nim function into a number of separate functions that we
#   can independely; each of these functions is what we call a "Leg".
#
# - it will create a new object type that is derived of our `Cont1`, on which it
#   will store all function arguments and local variables. This type is opaque
#   to us and is only used by CPS internally.
#
# The cps macro is a bit special, as it is typed: when calling the macro, the
# user needs to specify the type on which the macro should operate, and this
# type needs to be a derivative of the Continuation root object. This is what
# the notation looks like:

proc hello() {.cps:Cont1.} =
  echo "Hello, world!"

# Congratulations! we have now written our very first CPS program. Nim will now
# know all that is needed to do the transformation on our procedure at compile
# time so it will run our code CPS style.
#
# The next thing to do would be to run our CPS transformed function. This
# involves a few steps we'll go through:
#
# We start with instantiating the continuation: this means CPS will allocate a
# continuation object and prepare it so that it will point to the first leg of
# our function. Creating this instance is done with the `whelp` macro, and
# looks like this:
#
# TODO I still hate whelp. not the word, but the fact that we need it at all. I'd
#      rather just do var c = hello(). Yeah yeah I know.

var c: Continuation = whelp hello()

# For technical reasons, the whelp macro returns a derived type, which we need to 
# convert back to the `Continuation` type to be able to work with it.
#
# TODO Is there really no way around this?
#
# Our continuation is now ready to be run; in fact, it has already started!
# There is a little function to check the state of a continuation, and the one
# above is now in the state called `Running`. You can inspect the current state
# of a continuation like this:

doAssert c.state == Running

# or, shorter:

doAssert c.running()

# Now, to run the rest of our function (_continue_ it!), we need to do a little
# function call dance, which in the world of CPS is called `trampolining`: we
# call the `fn()` proc that is in the object, and pass the object itself to it.
# The result of this function call is again a continuation. Calling the `fn()`
# function once will run exactly one leg of our function:

c = c.fn(c)

# The result of the above call will be "Hello, world!" printed to your terminal!
# 
# Our original function was not very exciting and did not do much; after printing
# the text, it is done and finished - all the work could be done in one single leg.
# This means the continuation is now done and complete:

doAssert c.state == Finished

# or again, the shorthand

doAssert c.finished

# In real life, your CPS functions will have more then one leg. You would
# typically want to call the `fn()` proc repeatedly until the continunation
# is no longer running. This is a typical CPS idiom, and looks like this:
#
#   while c.running:
#     c = c.fn(c)
#
# Running the continuation legs in a row is called "trampolining", look at
# the diagram below to see why:
#
# whelp -.     ,---.     ,---.     ,---.     ,---.     ,--> fihisned
#         \   /     v   /     v   /     v   /     v   /
#        +-----+   +-----+   +-----+   +-----+   +-----+
#        | leg |   | leg |   | leg |   | leg |   | leg |
#        +-----+   +-----+   +-----+   +-----+   +-----+
#


# A MORE ELABOREATE EXAMPLE: COOPERATIVE SCHEDULING
# =================================================
#
# The above function was pretty simply and minimal, as it was transformed to
# only one single leg; it served the purpose of showing how to instantiate and
# run a CPS function.
#
# Let's go a bit deeper now. The essence of CPS is that our functions can be
# split into legs that can be run at leisure; one typical example of this would
# be cooperative scheduling, where we can run multiple CPS functions
# concurrently.
#
# For a simple example, let's write a little function with a loop - just a
# normal regular Nim function, which we will change later to run concurrent
# using CPS:

proc runner1(name: string) =
  var i = 0
  while i < 4:
    inc i
    echo name, " ", i

# So let's call the function to see if it works:

runner1("donkey")

# The output of this function call looks like this:
#
#   donkey 1
#   donkey 2
#   donkey 3
#   donkey 4
#
# Now let's see how we can leverage CPS to run multiple instances of this
# function concurrently!
#
# Let's start with a place to store the continuations that we want to run. A
# deque is a good fit for this, this is a first-in-first-out queue where we can
# add new continuations on one side, and take them off to run them from the
# other side:

import deques

var work: Deque[Continuation]

# Now we need some code to run this work queue. It will have a pretty simple
# job: it takes one continuation of the queue and trampoline it until it is no
# longer running, and repeat until there is no more work on the queue:

proc runWork() =
  while work.len > 0:
    var c = work.popFirst()
    while c.running:
      c = c.fn(c)

# Now we will introduce the last important part for building CPS programs,
# which is a special kind of function with the silly name "cpsMagic". Hold on
# to your seat, because this is possibly the most confusing part of CPS:
#
# Let's first describe what a cpsMagic function looks like: it
#
# - is annotated with the {.cpsMagic.} pragma 
# - takes a continuation type as its first arguments 
# - has the same continuation type as its return value 
# - can only be called from within a CPS function
#
# When calling the function, you do not need to provide the first argument, as
# this will be injected by the CPS transformation at the call site. Also you do
# not need to consume its return value, as that is handled by CPS internally.
#
# Now this is where the magic comes in: cpsMagic functions can be used to alter
# the program flow of a CPS function: it has access to the current continuation
# that is passed as it's first argument, and it can return a continuation which
# will be used as the next leg in the trampoline.
#
# That sounds complicated, let's just write our first .cpsMagic. proc:

proc schedule(c: Cont1): Cont1 {.cpsMagic.} =
  work.addLast c
  return nil

# Let's see what happens when we call this:
#
# - The current continuation of the cps function will be passed as the first 
#   argument 'c'
#
# - The continuation 'c' is added to `work`, the dequeue of continuations
#
# - It returns `nil` - which means "no continuation". This will cause the
#   trampoline that is running the continuation to terminate.
#
# Summarizing the above, the `schedule()` function will move the current
# continuation to the work queue, and stop the trampoline.
#
# Remember that when calling a .cpsMagic. function from within cps, we do not 
# need to provide the first argument, nor handle the return type. To call
# the above function, simply do
#
#    schedule()
#
# It is now time to put the above pieces together. Let's take the example
# function we wrote before, and make the required changes:
#
# - Add the `{.cps:Cont1.}` pragma to make it into a CPS function
# - call `schedule()` in the loop to yield control

proc runner2(name: string) {.cps:Cont1.}=
  var i = 0
  while i < 4:
    inc i
    echo name, " ", i
    schedule()

# And that's it! Now we can instantiate the function into a continuation with
# the `whelp` macro. Let's do this twice to create two instances, and add the
# resulting continuations to the work queue:

work.addLast whelp runner2("donkey")
work.addLast whelp runner2("tiger")

# Now let's run this beast: 

runwork()

# And here is the output of our run:
#
#   donkey 1
#   tiger 1
#   donkey 2
#   tiger 2
#   donkey 3
#   tiger 3
#   donkey 4
#   tiger 4

