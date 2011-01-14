#!/usr/bin/env ruby
#  nmm
#
#  Created by Paolo Bosetti on 2011-01-12.
#  Copyright (c) 2011 University of Trento. All rights reserved.
#

require 'matrix'

class Vector
  if RUBY_VERSION.split(".").join.to_i < 190
    # Add method for division under Ruby 1.8.x
    def /(other); self * (1.0 / other); end
  end
  # More compact inspect version
  def inspect; "V[#{self.to_a * ","}]"; end
end

# @author Paolo Bosetti
# @todo Perhaps a new class Point could be added, made of a +Vector+ and 
#   of the +Numeric+ value of the function at +Vector+. This could make the 
#   code more clear and simplify the argument checking.
module NMM

# Class that implements a general n-dimensional simplex, defined as a set of 
# Vector instances.
# Note: the dimension attribute represents the dimension of the simplex, 
# i.e. the number of points it is made of.
# @author Paolo Bosetti
  class Simplex
    attr_reader :dimension, :points
    # @param [Integer] dim the dimension of the simplex (its number of points)
    # @raise [ArghumentError] if dim is not an Integer
    def initialize(dim)
      raise ArgumentError, "Need an integer" unless dim.kind_of? Integer
      @dimension = dim
      @points = []
      @ready = false
    end
    
    # Adds a new point to the Simplex as a couple of Vector and value.
    # If the simplex is not filled, it only adds the new point; otherwise
    # it replaces the last point with the new one.
    # @param [Vector] p point coordinates as a Vector instance of dimension @dimension - 1
    # @param [Numeric] v function value at p
    # @raise [ArgumentError] when v is not a Vector of size @dimension - 1
    def []=(p,v)
      raise ArgumentError, "Vector needed" unless p.kind_of? Vector 
      raise ArgumentError, "Wrong Vector size #{@p.size}" unless p.size == @dimension - 1
      if @points.size <= @dimension - 1
        @points << [p, v]
      else
        @points[-1] = [p,v]
      end
      @ready = false
    end
    
    # Perform the analysis of the Simplex. It actually sorts the point for 
    # function values in ascending order, then computes the centroid of the 
    # hyperface opposed to the worst point, then reflects the worst point
    # about the centroid.
    # Computation only gets performed if the @points array has changed since
    # the last call. You do not have to call this method since it gets 
    # automatically invoked when a new point is added to the Simplex.
    def analyse
      return if @ready
      @points = @points.sort {|a,b| a[1] <=> b[1] }
      v0 = @points[0][0] * 0
      @centroid = @points[0...-1].inject(v0) { |m,v| m + v[0] } / (@dimension - 1.0)
      @reflected = @centroid * 2.0 - @points[-1][0]
      @ready = true
    end
    
    # Gets the point of the Simplex where the function assumes it lowest (:l),
    # highest (:j), second highest (:g) value. Also gets the centroid of best 
    # hyperface (:c) and the reflected point (:r).
    # @param [Symbol] k the key of the desired point
    # @return [Array <Vector, Numeric>] a couple of a Vector and a Numeric value
    # @raise [ArgumentError] when k is not a Symbol
    def [](k)
      analyse unless @ready
      raise ArgumentError, "Expecting a Symbol" unless k.kind_of? Symbol
      case k
      when :l
        @points[0]
      when :h
        @points[-1]
      when :g
        @points[-2]
      when :c
        @centroid
      when :r
        @reflected
      else
        raise ArgumentError, "Unsupported key #{k.inspect}"
      end
    end
    
    # Overridden #inspect method.
    # @return [String] human readable description
    def inspect
      result = ""
      [:l, :h, :g, :c, :r].each do |k|
        result << "#{k}: #{self[k].inspect} "
      end
      result
    end
    
    # Computes the norm as a quadratic sum of all the combinations of 
    # point values.
    # @return [Float] the norm.
    def norm
      return nil unless @points.size == @dimension
      q = 0
      @points.combination(2) do |p|
        q += ((p[0][1] - p[1][1]) ** 2.0)
      end
      return Math::sqrt(q / (@dimension))
    end
  end # class Simplex

# Class that implements a general n-dimensional Nelder-Meade Method (NMM).
# @author Paolo Bosetti
  class Optimizer
    attr_reader :simplex, :status
    
    # The +Optimizer+ gets initialized with the following defaults:
    #     :dim   => 2,
    #     :exp_f => 1.5, 
    #     :cnt_f => 0.5,
    #     :tol   => 0.001
    # If no +args+ is specified, these are the defaults. Otherwise, the keys that 
    # are passed are merged with those defaults.
    # @param [Hash] args a +Hash+ of initialization values
    def initialize(args = {})
      @cfg = {
        :dim   => 2,
        :exp_f => 1.5, 
        :cnt_f => 0.5,
        :tol   => 0.001
      }
      @cfg.merge! args
      @simplex = Simplex.new(@cfg[:dim])
      @start_points = []
      @status = :filling
    end
    
    # Sets the starting points of the +Simplex+.
    # @param [Array] ary an +Array+ of +Vector+s
    # @raise [ArgumentError] unless +ary+ is an +Array+ of +@cfg[:dim]+ +Vector+s
    def start_points=(ary)
      raise ArgumentError, "Need an Array" unless ary.kind_of? Array
      raise ArgumentError, "Array size must be #{@cfg[:dim]}" unless ary.size == @cfg[:dim]
      content = true
      ary.each { |v|  content = false unless v.kind_of? Vector}
      raise ArgumentError, "Array elements must be Vectors" unless content
      @start_points = ary
    end
    
    # Adds a new point to the +Simplex+.
    # @param [Array <Vector,Numeric>] point a new point with its value.
    # @raise [ArgumentError] is point is not of the expected type
    # @return [Array <Vector,Numeric>] the new point
    def <<(point)
      raise ArgumentError, "Need an Array" unless point.size == 2
      raise ArgumentError, "point[0] must be Vector" unless point[0].kind_of? Vector 
      raise ArgumentError, "point[1] must be Numeric" unless point[1].kind_of? Numeric
      @simplex[point[0]] = point[1]
    end
    
    # Starts the minimization loop. It expects the block containing the 
    # function evaluation.
    # @example
    #   f = lambda {|point| point[0]**2 + point[1]**2}
    #   opt = NMM::Optimizer.new( :dim => 3, :tol => 1E-5)
    #   opt.start_points = [Vector[10,37],Vector[7,2],Vector[51,32]]
    #   opt.loop {|point| f.call(p)}
    # @param [Array] ary if given, it gets filled with the optimization path
    # @yield [point] the block must return the evaluation of the function in +point+
    # @yieldparam [Vector] point the point which the function has to be evaluated at
    # @yieldreturn [Float] the evaluation
    # @raise [ArgumentError] unless a block is given
    def loop(ary = nil)
      raise ArgumentError, "Block needed" unless block_given?
      fx = nil
      until converged? do
        next_point = step(fx)
        unless next_point[1] then
          puts "Reflecting at #{next_point}"
          fx = yield(next_point[0])
        else
          next_point[1] = yield(next_point[0]) if next_point[1] == 0
          self << next_point
          fx = nil
          log
        end
        ary << [next_point, @status] if ary.kind_of? Array
      end
    end
    
    # This method prints out the track of the optimization.
    # @note You should override this method if you want to have a different 
    #   printout of minimization path.
    def log
      values = [@simplex.points[-1][0].to_a, @simplex.points[-1][1],(@simplex.norm || 0)].flatten
      puts "New point at:\n [%9.3f,%9.3f] -> %9.5f ||%9.5f||" % values
    end
    
    # Returns if the loop has converged, i.e. if the norm is less than +@cfg[:tol]+
    # @return [Bool] true if the loop has converged
    def converged?
      n = @simplex.norm
      if n then
        @simplex.norm < @cfg[:tol]
      else
        false
      end
    end
    
    private
    def step(vr = nil)
      # Filling starting Simplex
      if @start_points.size > 0 then
        @status = :filling
        return [@start_points.shift, 0] 
      end
      
      # Reflecting Simplex
      unless vr
        @status = :reflecting
        return [@simplex[:r], nil]
      end
      
      # Checking Expansion/Contraction
      x_new = [@simplex[:r], vr]
      if vr < @simplex[:l][1] then
        # Expansion
        @status = :expansion
        x_new = [@simplex[:c] * (1 + @cfg[:exp_f]) - @simplex[:h][0], 0]
      else
        if vr >= @simplex[:h][1] then
          # Contraction
          @status = :contraction1
          x_new = [@simplex[:c] * (1 - @cfg[:cnt_f]) + @simplex[:h][0] * @cfg[:cnt_f], 0]
        else
          if @simplex[:g][1] < vr and vr < @simplex[:h][1] then
            # Contraction
            @status = :contraction2
            x_new = [@simplex[:c] * (1 + @cfg[:cnt_f]) - @simplex[:h][0], 0]
          end
        end
      end
      return x_new
    end
    
  end # class Optimizer
end # module NMM




if __FILE__ == $0 then
  # Test function
  f = lambda { |p| p[0]**2 + p[1]**2  }
  
  # Instantiate the optimizer, with tolerance and dimension (it is the dimension
  # of the simplex, so number of parameters + 1 !!!)
  opt = NMM::Optimizer.new( :dim => 3, :tol => 1E-5)
  
  # Define the starting points, i.e. the first guess simplex
  opt.start_points = [
    Vector[10,37],
    Vector[7,2],
    Vector[51,32] 
  ]
  
  # Start the loop, passing a block that evaluates the function at the point
  # represented by the block parameter p
  # For different logging, just override the Optimizer#log method
  opt.loop {|p| f.call(p)}
  
  # Final simplex configuration is available at the end.
  p opt.simplex
  
  # In order to save track of the solution, pass an existing array to the 
  # Optimizer#loop method:
  # ary = []
  # opt.loop(ary) {|p| f.call(p)}
  # puts "***"
  # p ary
end