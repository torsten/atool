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


filt_stdin, filt_stdout, filt_stderr = Open3.popen3('c++filt')


# put it all together
`otool -tV '#{exe}'`.lines.
  map do |line|
    if line =~ /^__.+:$/
      filt_stdin.puts line
      "#{filt_stdout.gets.chop}\n#{line}"
      
    elsif line =~ /calll\s+(__.+)$/
      filt_stdin.puts $1
      "; #{filt_stdout.gets.chop}\n#{line}"
      
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
    
  end.each do |patched_line|
    puts patched_line
  end


filt_stdin.close
