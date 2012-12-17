require 'kl/compiler'
require 'kl/primitives/symbols'
require 'kl/primitives/strings'
require 'kl/primitives/assignments'
require 'kl/primitives/error_handling'
require 'kl/primitives/lists'
require 'kl/primitives/generic_functions'
require 'kl/primitives/vectors'
require 'kl/primitives/streams'
require 'kl/primitives/time'
require 'kl/primitives/arithmetic'

module Kl
  class Environment
    include ::Kl::Primitives::Symbols
    include ::Kl::Primitives::Strings
    include ::Kl::Primitives::Assignments
    include ::Kl::Primitives::ErrorHandling
    include ::Kl::Primitives::Lists
    include ::Kl::Primitives::GenericFunctions
    include ::Kl::Primitives::Vectors
    include ::Kl::Primitives::Streams
    include ::Kl::Primitives::Time
    include ::Kl::Primitives::Arithmetic

    def initialize
      # The variable namespace
      @tramp_fn = @tramp_args = @tramp_form = nil
      @variables = {}
      set("*stinput*".to_sym, STDIN)
      set("*stoutput*".to_sym, STDOUT)
    end

    # Associate proc p with the specified name in the function namespace
    def __defun(name, p)
      puts "  defun #{name}" if @trace
      eigenklass = class << self; self; end
      eigenklass.send(:define_method, name, p)
    end

    def __function(obj)
      p = case obj
          when Proc
            obj
          when Symbol
            method(obj).to_proc
          else
            raise "function applied to #{obj.class}"
          end
      p.curry
    end

    # Trampoline-aware function application
    def __apply(fn, args, f)
      puts "--> #{f} #{args}" if @trace
      result = fn.call(*args)
      while @tramp_fn
        fn = @tramp_fn
        args = @tramp_args
        f = @tramp_form
        @tramp_fn = nil
        @tramp_args = nil
        @tramp_form = nil
        puts "tail --> #{f} #{args}" if @trace
        result = fn.call(*args)
      end
      raise "boom: [#{f}]" if result.nil?
      result
    end

    def __eval(form)
      code = ::Kl::Compiler.compile(form, {}, true)
      result = instance_eval(code)
      # Handle top-level trampolines
      if @tramp_fn
        fn = @tramp_fn
        args = @tramp_args
        f = @tramp_form
        @tramp_fn = nil
        @tramp_args = nil
        @tramp_form = nil
        __apply(fn, args, f)
      else
        result
      end
    end

    class << self
      def load_file(env, path)
        File.open(path, 'r') do |file|
          reader = Kl::Reader.new(file)
          while form = reader.next
            env.__eval(form)
          end
        end
      end
    end
  end
end
