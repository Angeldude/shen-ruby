require 'spec_helper'

describe Kl::Environment do
  def eval_str(str)
    form = Kl::Reader.new(StringIO.new(str)).next
    @env.__eval(form)
  end

  before(:each) do
    @env = Kl::Environment.new
  end

  describe 'evaluation of atoms' do
    it 'evaluates symbols to themselves' do
      eval_str('foo').should == :foo
      eval_str('foo-bar-<baz>').should == "foo-bar-<baz>".to_sym
    end

    it 'evaluates strings to themselves' do
      eval_str('"foo"').should == 'foo'
      eval_str('"foo #{bar} \'baz"').should == 'foo #{bar} \'baz'
      eval_str('"\\"').should == '\\'
    end

    it 'evaluates numbers to themselves' do
      eval_str('1').should == 1
      eval_str('-1.7').should == -1.7
    end

    it 'evaluates booleans to themselves' do
      eval_str('true').should == true
      eval_str('false').should == false
    end
    
    it 'evaluations empty strings to themselves' do
      eval_str('()').should == Kl::EmptyList.instance
    end
  end

  describe 'evaluation of non-special forms' do
    it 'evaluates simple function application' do
      eval_str('(+ 1 2)').should == 3
    end

    it 'evaluates function arguments before application' do
      eval_str('(* (+ 1 2) (- 6 1))').should == 15
    end
  end

  describe 'evaluation of lambda special form' do
    it 'evaluates them to proc objects' do
      eval_str('(lambda X X)').should be_kind_of Proc
    end

    it 'allows them to be applied' do
      eval_str('((lambda X X) 37)').should == 37
      eval_str('((lambda X 42) ignore-me)').should == 42
    end

    it 'maintains lexical scoping' do
      # (let X 1
      #   (let Y 3
      #     (let X 7
      #       (+ X Y))))
      eval_str('((lambda X 
                   ((lambda Y 
                      ((lambda X (+ X Y)) 
                        7))
                     3)) 
                   1)').should == 10
    end

    it 'creates closures' do
      eval_str('((let X 37 (lambda IGNORE X)) ignore-me)').should == 37
    end
  end

  describe 'evaluation of let special form' do
    it 'binds its var' do
      eval_str('(let X 37 X)').should == 37
    end

    it 'maintains lexical scoping' do
      eval_str('(let X 1
                  (let Y 3
                    (let X 7
                      (+ X Y))))').should == 10
    end
  end

  describe 'evaluation of defun special form' do
    it 'adds a new function to the environment' do
      eval_str('(defun my-add (A B) (+ A B))').should == "my-add".to_sym
      eval_str('(my-add 17 20)').should == 37
    end

    it 'exposes the function for use in Ruby' do
      eval_str('(defun add7 (X) (+ X 7))')
      @env.add7(30).should == 37

      eval_str('(defun add14 (X) (add7 (add7 X)))')
      @env.add14(7).should == 21
    end

    it 'redefines existing functions' do
      eval_str('(defun my-fun () first-version)')
      eval_str('(my-fun)').should == :"first-version"
      eval_str('(defun my-fun () second-version)')
      eval_str('(my-fun)').should == :"second-version"
    end

    it 'adds a top-level function even when not executed at the top-level' do
      eval_str('((lambda X
                  (defun return-X () X)) 7)').should == :"return-X"
      eval_str('(return-X)').should == 7
    end

    it 'raises an error when attempting to redefine a primitive' do
      expect {
        eval_str('(defun + (A B) (* A B))')
      }.to raise_error(Kl::Error, '+ is primitive and may not be redefined')
    end
  end

  describe 'evaluation of boolean special forms' do
    describe "cond" do
      before(:each) do
        eval_str('(defun tr () true)')
        eval_str('(defun fa () false)')
      end

      it 'returns the value of the expression associate with the first true' do
        @env.should_not_receive(:tr)
        eval_str('(cond (false (tr))
                        ((fa) 37)
                        (true 42)
                        (true (tr)))').should == 42
      end

      it 'raises an error upon falling off the end' do
        expect {
          eval_str('(cond (false 37) ((fa) 42))')
        }.to raise_error(Kl::Error, 'condition failure')
      end
    end
  end

  describe "error handling" do
    it 'raises uncaught errors' do
      expect {
        eval_str('(simple-error "boom!")')
      }.to raise_error(Kl::Error, 'boom!')
    end

    it 'moves past caught errors' do
      eval_str('(trap-error 
                  (simple-error "boom!")
                  (lambda E 37))').should == 37          
    end

    it 'treats undefined functions as simple errors' do
      expect {
        eval_str('(foo)')
      }.to raise_error(Kl::Error, 'The function foo is undefined')
    end
  end

  describe "setting values" do
    it 'returns the value set' do
      eval_str('(set foo 37)').should == 37
    end

    it 'previously set values are retrievable' do
      eval_str('(set foo 37)')
      eval_str('(value foo)').should == 37
    end

    it 'raises an error when fetching an unset value' do
      expect {
       eval_str('(value foo)')
      }.to raise_error(Kl::Error, 'variable foo has no value')
    end
  end

  describe "evaluation of freeze" do
    it 'delays computation' do
      eval_str('(defun one () 1)')
      @env.should_not_receive(:one)
      eval_str('(freeze (one))').should be_kind_of Proc
    end

    it 'is thawable later' do
      eval_str('(defun one () 1)')
      eval_str('((freeze (one)))').should == 1
    end
  end

  describe 'evaulation of type' do
    it 'evaluates the expression and ignores the type information' do
      eval_str('(type (+ 1 2) number)').should == 3
    end
  end

  describe 'evaluation of eval-kl' do
    it 'evals as expected' do
      eval_str('(eval-kl (+ 1 2))').should == 3
    end
  end

  describe 'currying' do
    it 'supports partial application of primitives' do
      eval_str('((+ 1) 2)').should == 3
      eval_str('(((+) 1) 2)').should == 3
    end

    it 'supports partial application of user-defined functions' do
      eval_str('(defun adder (X Y) (+ X Y))')
      eval_str('((adder 1) 2)').should == 3
      eval_str('(((adder) 1) 2)').should == 3
    end

    it 'supports uncurrying of nested lambdas' do
      eval_str('((lambda X (lambda Y (* X Y))) 6 7)').should == 42
    end

    it 'supports uncurrying of higher-order functions' do
      eval_str('(defun adder (X) (lambda Y (+ X Y)))')
      eval_str('(adder 1 2)').should == 3
    end

    it 'raises an error of too many arguments are given' do
      expect {
        eval_str('((lambda X (lambda Y (* X Y))) 6 7 8)')
      }.to raise_error(Kl::Error, 'The value 42 is neither a function nor a symbol.')
    end
  end

  describe 'tail recursion' do
    it 'does not blow the stack' do
      eval_str('(defun count-down (X) 
                  (if (= X 0) 
                    success 
                    (count-down (- X 1))))')
      eval_str('(count-down 100000)').should == :success
    end
  end

  describe 'stack overflow' do
    it 'is translated into a Shen simple-error' do
      eval_str('(defun boom () (+ 1 (boom)))')
      expect {
        eval_str('(boom)')
      }.to raise_error(Kl::Error, 'maximum stack depth exceeded')
    end

    it 'doesn\'t overflow when do is in tail position' do
      eval_str('(defun factorial-h (X Acc)
                  (if (= X 0)
                      Acc
                      (do dummy (factorial-h (- X 1) (* X Acc)))))')
      expect {
        eval_str('(factorial-h 10000 1)')
      }.to_not raise_error
    end
  end

  describe 'optimized do expression' do
    it 'evaluates to the value of the second expression' do
      eval_str('(do (cn "fi" "rst") (cn "sec" "ond"))').should == "second"
    end

    it 'evaluates the first expression, then the second' do
      eval_str('(set temp-value 0)')
      eval_str('(do (set temp-value 10) (= 10 (value temp-value)))').should == true
    end

    it 'supports partial application' do
      eval_str('((do a) b)').should == :b
      eval_str('(((do) a) b)').should == :b
    end
  end
end
