#!/usr/bin/env ruby
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


methods = `otool -v -s __OBJC __message_refs '#{exe}'`.
  lines.
  map(&parse_lines).
  inject(Hash.new, &create_hash_from_lines)

classes = `otool -v -s __OBJC __cls_refs '#{exe}'`.
  lines.
  map(&parse_lines).
  inject(Hash.new, &create_hash_from_lines)


# use this to decode c++ symbols
filt_stdin, filt_stdout, filt_stderr = Open3.popen3('c++filt')

# fire up gdb to decode string references
gdb_stdin, gdb_stdout, gdb_stderr = Open3.popen3(
  "gdb -silent '#{exe}' 2>&1")

# ok, initializing a gdb is a bit more complicated
# send this 2 commands
gdb_stdin.puts('break main')
gdb_stdin.puts('run')
gdb_stdin.puts('set prompt')

# then read all output until we get an empty prompt
loop do
  begin
    buff = gdb_stdout.read_nonblock(2048)
    $stderr.puts "<<#{buff}>>"
    break if buff =~ /\(gdb\) $/m
  rescue Errno::EAGAIN
    sleep 1
  end
end

# gdb_stdin.puts "x /s *0x0002cc21"
# puts gdb_stdout.gets
# 
# exit


# (gdb) call (void)NSLog(@"%@", 0x0002cc2c)
# 2008-11-20 20:33:11.216 Twitterrific[2592:817] IFDeckAdConnection: refresh
# (gdb) x /s *0x0002cc2c
# 0xa07324a0 <__CFConstantStringClassReference>:   "`i-??$-?D\003H?"



# put it all together
`otool -tV '#{exe}'`.lines.
  each do |line|
    hrhr = if line =~ /^__.+:$/
      filt_stdin.puts line
      got_line = filt_stdout.gets
      
      if got_line != line
        "#{got_line.chop}\n#{line}"
      else
        
        line
      end
      
    elsif line =~ /calll\s+(__.+)$/
      filt_stdin.puts $1
      got_line = filt_stdout.gets
      
      if got_line.chop != $1
        "; #{got_line.chop}\n#{line}"
      else
        line
      end
      
    elsif line =~ /\$(0x[0-9a-f]{8})/
      addr = $1
      # $stderr.puts addr
      
      gdb_stdin.puts "x /x *#{addr}"
      gdb_says = gdb_stdout.gets

      # $stderr.puts gdb_says
      
      if gdb_says =~ /__CFConstantStringClassReference/
        gdb_stdin.puts "call (void)NSLog(@\"_:%@:_EOLOG\", #{addr})"
        gdb_says = gdb_stdout.readpartial(1024*1024*2)
        
        # $stderr.puts gdb_says
        
        if gdb_says =~ /.......... ............ .+\[.+\] _:(.*):_EOLOG$/m
          "#{line.chop} ; #{$1.inspect} (#{addr})\n"
        else
          # "#{line.chop} ;; !log: \"#{gdb_says}\" (#{addr})\n"
          line
        end
        
      else
        # "#{line.chop} ;; !str: \"#{gdb_says.chop}\" (#{addr})\n"
        line
        
      end
      
    elsif line =~ /movl.+0x([0-9a-f]{8})/
      key = $1.to_sym
      
      attach = if classes[key]
        " ; #{classes[key]}"
      elsif methods[key]
        " ; -[#{methods[key]}]"
      else
        ''
      end
      
      line.chop + attach + "\n"
      
    else
      line
    end
    
    puts hrhr
  end


filt_stdin.close
gdb_stdin.close
