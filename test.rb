#!/usr/bin/env ruby
#  test
#
#  Created by Paolo Bosetti on 2011-01-12.
#  Copyright (c) 2011 University of Trento. All rights reserved.
#

require "./lib/nmm"
require "./lib/scanner"

sc = Scanner.new :input_file => "input"
point = Vector[13,2.7,28.5]

sc.write_input {:var1 => point[0], :var2 => point[1], :var3 => point[2]}
puts "Written #{sc.line_count} lines with #{sc.error_count} errors"


exit
# Come funzionerà a regime:
opt = NMM::Optimizer.new( :dim => 3, :tol => 1E-5)
opt.start_points = [
  Vector[10,37],
  Vector[7,2],
  Vector[51,32] 
]
opt.loop do |p| 
  sc.write_input :var1 => point[0], :var2 => point[1], :var3 => point[2]
  system "deform #{sc.cfg[:input_file]}.txt"
  sc.read_output # MUST return a Vector!
end
