#!/usr/bin/env ruby
#  test
#
#  Created by Paolo Bosetti on 2011-01-12.
#  Copyright (c) 2011 University of Trento. All rights reserved.
#

require "./lib/nmm"



xh = Vector[1,1]
xl = Vector[5,7]
xg = Vector[9,2]
xc = (xl + xg) / 2
p xc * 2 - xh