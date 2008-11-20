#!/usr/bin/env ruby

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


# put it all together
`otool -tV '#{exe}'`.lines.
  map do |line|
    attach = ''
    if line =~ /movl.+0x([0-9a-f]{8})/
      key = $1.to_sym
      # [42 - line.size, 2].min
      
      attach = if classes[key]
        "   ; class #{classes[key]}"
      elsif methods[key]
        "   ; method #{methods[key]}"
      else
        ''
      end
    end
    line.chop + attach + "\n"
    
  end.each do |patched_line|
    puts patched_line
  end
