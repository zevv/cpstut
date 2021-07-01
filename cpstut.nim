
# INTRODUCTION
#
# What you are reading is a little tutorial to get started with Nim CPS. 
#
# The latest greatest CPS can be found at https://github.com/disruptek/cps
#
# This document written in the literate programming style, meaning that this is
# a readable document, but also a compilable and working Nim program.
#
# To run this program, call the nim compiler like so:
#
#   nim r --gc:arc csptut
#
# WHAT IS CPS
#
# For now I'll just point to the other documentation that is already available:
# please refer to the README of the disruptek/cps repository for a brief intro,
# or read up at https://github.com/zevv/cpsdoc for a more in-depth description
# of the concepts underlying the CPS transformation
#
# GETTING STARTED
#
# cps is available as a regular nim library that you must import before cps is
# available in your program. The module offers a number of macros and
# templates, for details refer to the module documentation at
# https://disruptek.github.io/cps/cps.html
#
# So we start with the import:

import cps

# THE CONTINUATION
#
# At the heart of CPS lies the `Continuation` type. In our implementation, this
# is just a regular Nim object that is inheritable. This is what the type looks like:
#
# Continuation = ref object of RootObj
#    fn*: proc (c: Continuation): Continuation {.nimcall.} ##
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
#
# THE CPS TRANSFORM MACRO
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
# Our continuation is now ready to go; actually, it has already started. There
# is a little function to check the state of a continuation, and the one above
# is now in the state called `Running`. You can inspect the current state of a
# continuation like this:

doAssert c.state == Running

# or, shorter:

doAssert c.running()

# Now, to run our function, we need to perform a special function call, which
# in the world of CPS is called `trampolining`: we call the `fn()` proc that is
# in the object, and pass the object itself to it. The result of this function
# call is again a continuation. Calling the `fn()` function once will run
# exactly one leg of our function:

c = c.fn(c)

# The result of the above call will be "Hello, world!" printed to your terminal!
# 
# Our original function was not very exciting and did not do much; after printing
# the text, it is done and finished - all the work could be done in one single leg.
# This means the continuation is now done and complete:

doAssert c.state == Finished

# or again, the shorthand

doAssert c.finished

