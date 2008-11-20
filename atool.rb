#!/usr/bin/env ruby

exe = $*.first

raise 'Usage: atool <file>' if exe.nil?


parse_lines = proc do |line|
  matches = line.match /^([0-9a-f]+)  __TEXT:__cstring:(.+)$/
  [matches[1].to_sym, matches[2]] if not matches.nil?
end

create_hash_from_lines = proc do |hsh, match|
  hsh[match[0]] = match[1] if not match.nil?
  hsh
end


methods = `otool -v -s __OBJC __message_refs '#{exe}'`
puts methods.lines.map(&parse_lines).inject(Hash.new, &create_hash_from_lines).inspect





# classes = `otool -v -s __OBJC __cls_refs '#{exe}'`

