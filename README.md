# ShenRuby
ShenRuby is a Ruby port of the [Shen](http://shenlanguage.org/) programming language. Shen is a modern, functional Lisp that supports pattern matching, currying, and optional static type checking.

ShenRuby supports Shen version 16, which was released in September, 2014.

The ShenRuby project has two primary goals. The first is to be a low barrier-to-entry means for Rubyists to explore Shen. To someone with a working installation of Ruby 1.9.3 or greater, a Shen REPL is only a gem install away.

Second, ShenRuby aims to enable hybrid applications implemented using a combination of Ruby and Shen. Ruby methods should be able to invoke functions written in Shen and vice versa. Performance is a secondary part of this goal. It should be good enough that, for most tasks, the choice between Ruby and Shen is based primarily on which language is best suited for solving the problem at hand.

ShenRuby 0.1.0 began to satisfy the first goal by providing a Shen REPL accessible from the command line. The second goal is more ambitious and is the subject of ongoing work leading up to the eventual 1.0.0 release.

[![Build Status](https://travis-ci.org/gregspurrier/shen-ruby.png)](https://travis-ci.org/gregspurrier/shen-ruby)

## Installation
NOTE: ShenRuby requires Ruby 1.9 language features. It is tested with Ruby 2.0.0, 2.1.5, and 2.2.0. It has been lightly tested with JRuby 1.7.17. It is functional with Ruby 1.9.3, however its fixed stack size prevents it from passing the Shen Test Suite (see [Setting Stack Size](setting-stack-size) below).

ShenRuby 0.11.0 is the current release. To install it as a gem, use the following command:

    gem install shen-ruby

## Getting started with the Shen REPL

Once the gem has been installed, the Shen REPL can be launched via the `srrepl` (short for ShenRuby REPL) command. For example:

    % srrepl
    Loading.... Completed in 2.18 seconds.

    Shen 2010, copyright (C) 2010 Mark Tarver
    released under the Shen license
    www.shenlanguage.org, version 16
    running under Ruby, implementation: ruby 2.2.0
    port 0.11.0 ported by Greg Spurrier


    (0-)

The `(0-)` seen above is the Shen REPL prompt. The number in the prompt increases after each expression that is entered.

Here is an example of defining a recursive factorial function via the REPL and trying it out:

    (0-) (define factorial
           0 -> 1
           X -> (* X (factorial (- X 1))))
    factorial

    (1-) (factorial 5)
    120

    (2-) (factorial 20)
    2432902008176640000

    (3-) (factorial 100)
    93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000

Shen functions are defined in terms of pattern matching rules. Above we say that the factorial of 0 is 1 and that the factorial of anything else--represented as the variable `X`--is `X` times the factorial of `(X - 1)`. This is very similar to how factorial would be described via mathematical equations.

As can be seen with `(factorial 100)`, ShenRuby uses Ruby's underlying number system and supports arbitrarily large integers.

For a quick tour of Shen via the REPL, please see the [Shen in 15 Minutes](http://www.shenlanguage.org/learn-shen/tutorials/shen_in_15mins.html) tutorial on the Shen Website. To learn more about using the Shen REPL itself, please see the [REPL](http://www.shenlanguage.org/learn-shen/repl.html) documentation, also on the Shen Website. Additional resources for learning about Shen are listed in the Shen Resources section below.

To exit the Shen REPL, execute the `quit` function:

    (4-) (quit)
    %

## Ruby<->Shen Interop
Bidirectional interaction between Ruby and Shen is a primary goal of ShenRuby. The following sections describe the currently supported means of collaboration between Shen and Ruby.

These APIs should be considered experimental and likely to evolve as ShenRuby progresses toward 1.0.

### Extending the Shen Environment with Ruby Functions

The Shen Environment may be extended with functions written in Ruby. Any instance method added to the ShenRuby::Shen class--whether through subclassing or adding methods to an instance's eigenclass--is available for invocation from within Shen.

For example, to add a `divides?` function to an existing Shen environment object:

    require 'rubygems'
    require 'shen_ruby'

    shen = ShenRuby::Shen.new
    class << shen
      def divides?(a, b)
        b % a == 0
      end
    end

### Evaluating Shen Expressions from Ruby
`ShenRuby::Shen#eval_string` takes a string and evaluates it as a Shen expression within the environment. For example, the `divides?` function added above may be invoked with:

    shen.eval_string "(divides? 3 9)"
    # => true

More commonly, though, `eval_string` is used with Shen `define` expressions to extend the environment with new functions that are implemented in Shen. For example, let's add a [Fizz Buzz](http://en.wikipedia.org/wiki/Fizz_buzz) function:

    shen.eval_string <<-EOS
      (define fizz-buzz
        X -> "Fizz Buzz" where (and (divides? 3 X)
                                   (divides? 5 X))
        X -> "Fizz" where (divides? 3 X)
        X -> "Buzz" where (divides? 5 X)
        X -> (str X))
    EOS
    # => :"fizz-buzz"

### Invoking Shen Functions from Ruby

Shen functions are instance methods of the ShenRuby::Shen environment object. Functions having names that are valid Ruby method names may be invoked directly:

    shen.cn("Hello, ", "Shen!")
    # => "Hello, Shen!"

If the Shen function's name is not a valid Ruby method name--e.g. it includes a hyphen--it can be invoked via `__send__`:

    shen.__send__('fizz-buzz', 15)
    # => "Fizz Buzz"

Ruby arrays must be converted to Shen lists or vectors before passing to Shen. Here is an example of converting an array to a list, invoking Shen's `map` function, and converting the resulting list back to a Ruby array:

    ShenRuby.list_to_array(shen.map(:'fizz-buzz', ShenRuby.array_to_list((1..20).to_a)))
    => ["1", "2", "Fizz", "4", "Buzz", "Fizz", "7", "8", "Fizz", "Buzz", "11", "Fizz", "13", "14", "Fizz Buzz", "16", "17", "Fizz", "19", "Buzz"]

The equivalent conversion functions for vectors are `ShenRuby.vector_to_list` and `ShenRuby.list_to_vector`.

#### Caveats
Shen function invocation via methods on the Shen object only works for normal functions. It will not work for special forms like `define` or macros.

## Setting Stack Size
Some operations in Shen, notably type checking of complicated types, require more stack space than is available by default in Ruby. If your program encounters a stack overflow, you can increase Ruby's stack size through the following methods.

### Ruby
Beginning in Ruby 2.0.0, the MRI stack size can be overridden via the `RUBY_THREAD_VM_STACK_SIZE` environment variable. A value of 2097152 is sufficient for the Shen Test Suite to pass under both OS X and Linux.

### JRuby
JRuby uses the JVM's stack. It can be increased via the `-J-Xss` command line argument. A value of 32m (i.e., `-J-Xss32m`) is sufficient for the Shen Test Suite to pass under both OS X and Linux.

## Shen Resources

The following resources may be helpful for those wanting to learn more about the Shen programming language:

- [The Shen Website](http://shenlanguage.org/)
- [Learn Shen](http://www.shenlanguage.org/learn-shen/index.html) -- The Shen Website's suggested resources for--and approaches to--learning Shen, including the [Shen in 15 Minutes](http://www.shenlanguage.org/learn-shen/tutorials/shen_in_15mins.html) tutorial for experienced functional programmers.
- [The Shen Official Standard](http://www.shenlanguage.org/Documentation/shendoc.htm)
- [System Functions and their Types in Shen](http://www.shenlanguage.org/learn-shen/system.pdf) -- A reference for all of the standard Shen functions and their types.
- [The Book of Shen (Second Edition)](http://www.fast-print.net/bookshop/1506/the-book-of-shen-second-edition) -- The official guide to the Shen programming language.
- [Shen Google Group](https://groups.google.com/group/qilang?hl=en) -- This is the online forum for discussions related to Shen.

## Road Map to 1.0

The following features and improvements are among those planned for ShenRuby as it approaches its 1.0 release:

- Ability to call Ruby methods directly from Shen
- Support for command-line Shen scripts that under ShenRuby
- Support for Rubinius
- Thread-safe `ShenRuby::Shen` instances

## Known Limitations
- ShenRuby fails with a stack overflow when run under cygwin on Windows ([Issue #3](https://github.com/gregspurrier/shen-ruby/issues/3)). The Ruby environment installed by [RubyInstaller](http://rubyinstaller.org/), however, is capable of running ShenRuby. It is the recommended environment for running ShenRuby on Windows until the stack overflow issues seen on cygwin can be addressed.
- ShenRuby fails to load under Rubinius ([Issue #7])(https://github.com/gregspurrier/shen-ruby/issues/7)].

## Contributors
The following people are gratefully acknowledged for their contributions to ShenRuby:

- Brian Shirai
- Bruno Deferrari

## License
Shen and ShenRuby are released under the Shen License. A copy of the Shen License may be found in [shen/license.txt](https://github.com/gregspurrier/shen-ruby/blob/master/shen/license.txt). A detailed description of the license, along with questions and answers, may be found at http://shenlanguage.org/license.html. In particular, please note that any forks or derivatives of ShenRuby must maintain conformance with the Official Shen Specification.

The implementation of Shen, which is found in the [shen/release](https://github.com/gregspurrier/shen-ruby/tree/master/shen) directory, is Copyright (c) 2010-2014 Mark Tarver and may only be used in accordance with the Shen License.

The remainder of the code for ShenRuby is Copyright(c) 2012-2015 Greg Spurrier. It may be used outside of the context of ShenRuby under the terms of the MIT License. A copy of the MIT License may be found in [MIT_LICENSE.txt](https://github.com/gregspurrier/shen-ruby/blob/master/MIT_LICENSE.txt).
