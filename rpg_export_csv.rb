require_relative 'lib/vxlib'

def val(obj, vxace: RGSS.current.ace?) # rubocop:disable CyclomaticComplexity, PerceivedComplexity
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

require 'csv'

def data_export(name, filter, rgss: RGSS.current, output_file: STDOUT)
  ary  = ptr(ptr(rgss.globals[name]) + 4) # => data
  flgs = ptr(ary)
  len  = (flgs & (1 << 13)) > 0 ? 3 : ptr(ary + 8)
  ary_buf = ProcessMemoryEx.latest.ptr_fmt(ptr(ary + 16), 4 * len, 'V*')
  obj = RGSS3Object.new ary_buf[1]
  CSV(output_file){|csv|
    ary_buf.each{|addr|
      obj = val addr # RGSS3Object.new addr
      next unless obj
      csv << filter.map{|nm| val(obj[nm]) }
    }
  }
end

puts '$data_itemsを標準出力にCSVで出力'
data_export '$data_items', %w[@id @name @price]

puts '$data_weaponsをdata_weapons.csvに出力'
open('data_weapons.csv', 'w:utf-8'){|f|
  f.write "\ufeff" # BOM付与
  data_export '$data_weapons', %w[@id @name], output_file: f
}
