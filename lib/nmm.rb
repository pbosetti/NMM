#!/usr/bin/env ruby
#  nmm
#
#  Created by Paolo Bosetti on 2011-01-12.
#  Copyright (c) 2011 University of Trento. All rights reserved.
#

require 'matrix'

if RUBY_VERSION.split(".").join.to_i < 190
  # Add method for division under Ruby 1.8.x
  class Vector
    def /(other); self * (1.0 / other); end
  end
end


module NMM

  class Simplex
    attr_reader :dimension, :points
    def initialize(dim)
      @dimension = dim
      @points = []
      @ready = false
    end
    
    def []=(p,v)
      raise ArgumentError, "Vector needed" unless p.kind_of? Vector and p.size == @dimension - 1
      if @points.size <= @dimension - 1
        @points << [p, v]
      else
        @points[-1] = [p,v]
      end
      @ready = false
    end
    
    def analyse
      return if @ready
      @points = @points.sort {|a,b| a[1] <=> b[1] }
      v0 = @points[0][0] * 0
      @centroid = @points[0...-1].inject(v0) { |m,v| m + v[0] } / (@dimension - 1.0)
      @reflected = @centroid * 2.0 - @points[-1][0]
      @ready = true
    end
    
    def [](k)
      analyse unless @ready
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
    
    def inspect
      result = ""
      [:l, :h, :g, :c, :r].each do |k|
        result << "#{k}: #{self[k].inspect} "
      end
      result
    end
    
    def norm
      q = 0
      @points.combination(2) do |p|
        q += ((p[0][1] - p[1][1]) ** 2.0)
      end
      return Math::sqrt(q / (@dimension))
    end
  end # class Simplex

  class Optimizer
    attr_reader :simplex
    
    def initialize(args = {})
      @cfg = {
        :dim   => 2,
        :exp_f => 1.5, 
        :cnt_f => 0.5,
        :tol   => 0.001
      }
      @cfg.merge! args
      @simplex = Simplex.new(@cfg[:dim])
    end
    
    def <<(point)
      raise ArgumentError unless point[0].kind_of? Vector and point[1].kind_of? Numeric
      @simplex[point[0]] = point[1]
    end
    
    def hint
      @simplex[:r]
    end
    
    def step(vr)
      x_new = @simplex[:r]
      if vr < @simplex[:l][1] then
        # Expansion
        x_new = @simplex[:c] * (1 + @cfg[:exp_f]) - @simplex[:h][0]
      else
        if vr >= @simplex[:h][1] then
          # Contraction
          x_new = @simplex[:c] * (1 - @cfg[:cnt_f]) + @simplex[:h][0] * @cfg[:cnt_f]
        else
          if @simplex[:g][1] < vr and vr < @simplex[:h][1] then
            # Contraction
            x_new = @simplex[:c] * (1 + @cfg[:cnt_f]) - @simplex[:h][0]
          end
        end
      end
      return x_new
    end
    
    def check
      return @simplex.norm < @cfg[:tol]
    end
    
  end # class Optimizer
end # module NMM

if __FILE__ == $0 then
  f = lambda { |p| p[0]**2 + p[1]**2  }
  opt = NMM::Optimizer.new( :dim => 3, :tol => 1E-5)
  start_points = [
    Vector[10,37],
    Vector[7,2],
    Vector[-51,32] 
  ]
  start_points.each { |p| opt << [p, f.call(p)] }
  
  until opt.check do
    x_r = [opt.hint, f.call(opt.hint)]
    puts "Reflecting at #{x_r.inspect}"
    x_n = opt.step(x_r[1])
    opt << [x_n, f.call(x_n)]
    puts "New point at #{opt.simplex.points[-1]}, norm #{opt.simplex.norm}"
  end
end