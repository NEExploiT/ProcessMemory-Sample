# なんとなく造ったプラネットドラゴン体験版用
# 交易品を列挙するだけのスクリプト

# お約束
require 'ProcessMemory.rb'
include ProcessMemory
# 省略記法を許すためのお約束
include ProcessMemoryUtil
# プロセス指定
$mem = memoryutil_startup

# utf16leを適当に読み込む関数
def wstr(pointer, bufmax = 0x1000)
  r = $mem.ptr_fmt(pointer, bufmax, 'v*')
  s = r.take_while { |it| it != 0 }.pack('v*')
  s.force_encoding Encoding::UTF_16LE
end

base = ptr(ptr(ptr(ptr(ptr(ptr(MName('planet.exe') + 0x130a) + 0x238) + 0xe8) + 0x64) + 0x18c) + 0x3C) - 0x10

adjust_offset = -0x10 # 体験版は 0
len  = ptr(base + 0x77B64 + adjust_offset)
ary  = ptr(base + 0x77B60 + adjust_offset)

(0...len).each do |x|
  it = ary + x * 24
  num      = ptr(it)               # 4
  name     = wstr(ptr(it + 4))     # 8
  category = wstr(ptr(it + 8))     # 12
  santi    = wstr(ptr(it + 0xC))   # 16
  icon     = ptr(it + 0x10)        # 20
  descript = wstr(ptr(it + 0x14))  # 24

  # puts name
  # puts category
  # puts santi
  category8 = category.encode Encoding::UTF_8
  name8     = name.encode Encoding::UTF_8
  puts "#{num} = [#{category8}]#{name8}(#{icon})"
end
