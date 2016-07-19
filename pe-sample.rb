require_relative 'lib/pe'

pe = PELib.new ProcessMemoryEx.new ProcessMemory::ProcessMemoryUtil::memoryutil_startup
base = pe.base_addr

def build_expr(base, name, ix, offset)
  "_ (MName::#{name}) => base;[:$base + 0x3C:] + 4 + $base => fh;" +
  "[:($fh + 20 + ([:$fh + 16:] & 0xFFFF)) + 40 * #{ix} + 12:] => va;" +
  format('$base+$va+0x%0X', offset)
end

def build_expr_tenuki(base, name, ix, offset, pe)
  fh = pe.ptr_i32(base+0x3C) + 4 + base

  va_offset = fh + 0x14 + (pe.ptr_i32(fh + 0x10) & 0xFFFF) + 0x28 * ix + 12
  va_offset -= base

  "_ (MName::#{name}) => base;" +
  "[:$base+#{va_offset}:] => va;" +
  format('$base+$va+0x%0X', offset)
end

def build_expr_usamimi(base, name, ix, offset)
  "h = ptr(g + 0x3C) + 4 + g\n" +
  "i = ptr(h + 0x14 +(ptr(h + 0x10) & 0xFFFF) + 0x28 * 0x#{ix.to_s 16} + 0x0C)\n" +
  format('g + i + 0x%0X', offset)
end

print "input:"
while (addr = gets.hex) != 0
  ix, sec = pe.offset_of addr
  if ix
    va = sec.VirtualAddress
    offset = addr - base - va
    puts format('0x%08X = 0x%08X + 0x%08X + 0x%08X',addr, base, va, offset)
    puts build_expr(base, pe.base_name, ix, offset)
    puts build_expr_usamimi(base, pe.base_name, ix, offset)
    puts build_expr_tenuki(base, pe.base_name, ix, offset, pe)
  else
    puts format('0x%08X is not found', addr)
  end
  print "input:"
end
