require './lib/vxlib'

cur = RGSS.current

def val(obj, vxace: RGSS.current.ace?)
  if obj & 3 != 0
    return obj >> 1 if obj & 1 == 1
    return true if obj == 2
    return RGSS.current.key_to_name obj
  elsif (obj & ~4).zero?
    return nil if obj == 4
    return false if obj.zero?
  end
  if vxace
    case ptr(obj) & 0x1F
    when 5 then RGSSString.new obj, vxace
    when 1 then RGSS3Object.new(obj)
    else raise '未実装'
    end
  else
    case ptr(obj) & 0x3F
    when 7 then RGSSString.new obj
    when 2 then RGSS2Object.new(obj)
    else raise '未実装'
    end
  end
end

ary_bs   = cur.globals['$data_items']
ary      = ptr(ptr(ary_bs) + 4) # => data
ary_flgs = ptr(ary)
ary_len  = (ary_flgs & (1 << 13)) > 0 ? 3 : ptr(ary + 8)
ary_buf  = ProcessMemoryEx.latest.ptr_fmt(ptr(ary + 16), 4 * ary_len, 'V*')
obj = RGSS3Object.new ary_buf[1]
ary_buf.each{|addr|
  obj = val addr # RGSS3Object.new addr
  next unless obj
  puts %w[@id @name @price].map{|name| val(obj[name]) }.join "\t"
}