Welcome to El Compilador, a compiler for Emacs Lisp.

## Breaking News

The compiler can now generate C code that can be compiled as part of
Emacs.  Using the bubble sort benchmark from
http://www.emacswiki.org/emacs/EmacsLispBenchmark (with the list
bumped to 1000 elements), with 100 runs, I got some timings:

Approach | Seconds
:-------- | -------:
interpreted | 54.874574673000005
byte-compiled | 13.390510359999999
el-compilador | 4.312016277000001

## Dreams

I've long wanted to write a compiler for Emacs Lisp.  Here it is.
Well, the start of it.  In the long term I have a few goals for Emacs
and Emacs Lisp that are served by this project:

I think Emacs should move more strongly toward self-hosting.  Too much
of Emacs is written in C, and in the long term this should be migrated
to lisp.  Beyond just being more fun to hack, having Emacs written in
Emacs Lisp would make it simpler to upgrade the language
implementation.

There are plenty of functions currently written in C which were either
translated for performance (`widget-apply`) or just because some other
part of the core needed to call it.  These would stop being acceptable
reasons to write in C.

The C core is also badly behaved about making direct calls.  This is
ok for primitives like `cons`, but not ok for functions that one might
reasonably want to advise or rewrite, like `read`.  Normally this lack
of indirection is just because it is a pain to write out in C -- but
automatic translation could eliminate this problem.

I'm also interested in using the compiler to either write a JIT or a
new register-based bytecode interpreter.  These could be done without
modifying Emacs once the new FFI code lands.

Finally, it is bad and wrong that Emacs has three bytecode
interpreters (the Emacs Lisp one, the regexp engine, and CCL).  There
should be only one, and we can use this work to push Emacs toward that
goal.

## Use

You can use the function in `loadup.el` to load the compiler and then
use the two handy entry points:

* `elcomp--do`.  The debugging entry point.  This takes a form,
  compiles it, and then dumps the resulting IR into a buffer.  For
  example, you can try this on a reasonably direct translation of
  `nthcdr` from `fns.c`:

```elisp
(elcomp--do '(defun nthcdr (num list)
               (cl-check-type num integer)
               (let ((i 0))
                 (while (and (< i num) list)
                   (setq list (cdr list))
                   (setq i (1+ i)))
                 list)))
```

* You can pass `elcomp--c-translate` as the third argument to
  `elcomp--do` to use the "C" back end.  At least some forms of the
  output will compile.  It targets the API used by the Emacs source
  tree (not the Emacs dynamic module API).  Some constructs don't have
  the needed back end support yet, so not everything will work.

## Implementation

El Compilador is an
[SSA-based](http://en.wikipedia.org/wiki/Static_single_assignment_form)
compiler.  The objects in the IR are described in `elcomp.el`.  EIEIO
or `cl-defstruct` are used for most things.

The compiler provides a number of optimization passes:

* Jump threading, `elcomp/jump-thread.el`.  This also does some simple
  optimizations on predicates, like `not` removal.  This can sometimes
  turn a `throw` into a `goto` when it is caught in the same `defun`.

* Exception handling cleanup, `elcomp/eh-cleanup.el`.  This removes
  useless exception edges.

* Block coalescing, `elcomp/coalesce.el`.  This merges basic blocks
  when possible.

* Constant and copy propagation, `elcomp/cprop.el`.  This also
  evaluates pure functions.

* Dead code elimination, `elcomp/dce.el`.

* Type inference, `elcomp/typeinf.el`.  This is a flow-sensitive type
  inferencer.


## To-Do

There are any number of bugs.  There are some notes about them in
various files.  Some are filed in the github issues.

The into-SSA pass is written in the stupidest possible way.  Making
this smarter would be nice.
