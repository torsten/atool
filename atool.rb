#!/usr/bin/env ruby

# Copyright (C) 2008 Torsten Becker <torsten.becker@gmail.com>.
# All rights reserved.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER 
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# atool.rb, created on 2008-Nov-20.

raise 'atool just runs with ruby-1.8.7 or higher' if RUBY_VERSION < '1.8.7'

require 'open3'


exe = $*.first
raise 'Usage: atool <file>' if exe.nil?


parse_lines = proc do |line|
  [$1.to_sym, $2] if line =~ /^([0-9a-f]+)\s+__TEXT:__cstring:(.+)$/
end

create_hash_from_lines = proc do |hsh, match|
  hsh[match[0]] = match[1] if not match.nil?
  hsh
end


# Create the lookup hashes for methods and classes to resolve plain addresses
methods = `otool -v -s __OBJC __message_refs '#{exe}'`.
  lines.map(&parse_lines).inject(Hash.new, &create_hash_from_lines)

classes = `otool -v -s __OBJC __cls_refs '#{exe}'`.
  lines.map(&parse_lines).inject(Hash.new, &create_hash_from_lines)


# Use this to decode C++ symbols
filt_stdin, filt_stdout, filt_stderr = Open3.popen3('c++filt')

# Fire up gdb to decode string references
gdb_stdin, gdb_stdout, gdb_stderr = Open3.popen3("gdb -silent '#{exe}' 2>&1")

# Set an empty prompt
gdb_stdin.puts('set prompt')

# Then read all output until we get an empty prompt
loop do
  begin
    buff = gdb_stdout.read_nonblock(2048)
    $stderr.puts "<<#{buff}>>"
    break if buff =~ /\(gdb\) $/m
  rescue Errno::EAGAIN
    sleep 1
  end
end


# This is how to decode/enhance a single line
enhance_line = proc do |line|
  
  new_line =
  
  # Decode C++ symbols
  if line =~ /^__.+:$/
    filt_stdin.puts line
    got_line = filt_stdout.gets
    
    if got_line != line
      "#{got_line.chop}\n#{line}"
    else
      line
    end
  
  # Decode C++ call and insert a comment before the line
  elsif line =~ /calll\s+(__.+)$/
    filt_stdin.puts $1
    got_line = filt_stdout.gets
    
    if got_line.chop != $1
      "; #{got_line.chop}\n#{line}"
    else
      line
    end
  
  # Resolve unnamed symbols using gdb and then try to decode the line again
  elsif line =~ /^([0-9a-f]{8}).+\$__unnamed\w+/
    addr = $1
    
    gdb_stdin.puts "x /i 0x#{addr}"
    gdb_says = gdb_stdout.gets
    
    # Example result: 0x3133 <-[...:]+39>:	movl   $0xe3828,0x8(%esp)
    
    if gdb_says =~ /\$0x([0-9a-f]+)/
      replacement = "$0x#{'0' * (8 - $1.size) + $1}"
      # Recursion:
      enhance_line.call(line.gsub(/\$__unnamed\w+/, replacement))
      nil
      
    else
      line
    end
  
  # This is how string references usually look like
  elsif line =~ /\$(0x[0-9a-f]{8})/
    addr = $1
    
    gdb_stdin.puts "x /x (#{addr}+4)"
    gdb_says = gdb_stdout.gets
    
    # $stderr.puts addr
    # $stderr.puts gdb_says
    
    # This seems to be the signature for a string :>
    if gdb_says =~ /0x000007c8$/
      gdb_stdin.puts "x /s *(#{addr}+8)"
      gdb_says = gdb_stdout.gets
      
      # $stderr.puts gdb_says
      
      if gdb_says =~ /\>:\s+(".*"(\.\.\.)?)$/
        "#{line.chop} ; #{$1}\n"
      else
        "#{line.chop} ; (gdb) #{gdb_says}\n"
      end
      
    else
      # "#{line.chop} ;; !str: \"#{gdb_says.chop}\" (#{addr})\n"
      line
      
    end
  
  # This is the usual pattern for a class or method reference
  elsif line =~ /movl.+0x([0-9a-f]{8})/
    key = $1.to_sym
    
    attach = if classes[key]
      " ; #{classes[key]}"
    elsif methods[key]
      " ; [#{methods[key]}]"
    else
      ''
    end
    
    line.chop + attach + "\n"
    
  else
    line
  end
  
  puts new_line unless new_line.nil?
  
end


# Put it all together
`otool -tV '#{exe}'`.lines.each &enhance_line


filt_stdin.close
gdb_stdin.close
