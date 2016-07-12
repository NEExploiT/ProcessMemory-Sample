# coding: utf-8
# ウディタv2.10製ゲームの通常/予備変数/文字列変数/可変データベースを全てダンプする
require './lib/ProcessMemory.rb'
require './lib/wditor_lib.rb'
require 'csv'

puts "ウディタv2.10製ゲームの通常/予備変数/文字列変数/可変データベースを全てダンプする"

mem = WditString.proccess = memoryutil_startup

def db(addr, type = nil, id = nil, col = nil)
  return DataBase_Info.new addr unless type
  return DataBase_Type.new addr, type unless id
  return DataBase_Id.new addr, type, id unless col
  DataBase_Col.new addr, type, id, col
end

def udb(type = nil, id = nil, col = nil)
  db(USER_DATABASE_BASE, type, id, col)
end
def vdb(type = nil, id = nil, col = nil)
  db(VAR_DATABASE_BASE, type, id, col)
end
def sdb(type = nil, id = nil, col = nil)
  db(SYS_DATABASE_BASE, type, id, col)
end

def value_hexlize val
  return val unless val.is_a?(Integer)
  if val > 999_999
    "0x" + val.to_s(16)
  elsif val < -999_999
    "-0x" + val.abs.to_s(16)
  else
    val
  end
end

print(
  CSV.generate("", encoding:'cp932') do |csv|
    # 通常変数
    (14..22).each.with_index{|t, it|
      csv << ["# 変数 v#{it}"]
      sdb(t).keys.each.with_index{|name, ix|
        csv << ["v#{it}[#{ix}]", name, value_hexlize(ptr(ptr(ptr(VAR_BASE)+it*0x10+0x04)+ix*0x04))]
      }
    }
    # 文字変数
    csv << ['# 文字変数 s']
    svkeys = sdb(4).keys
    WditStringArray.new(SVAR_BASE).to_a.each.with_index{|s, ix|
      csv << ["s[#{ix}]", svkeys[ix], s]
    }
    # 可変データベース
    vdb.keys.each.with_index{|tname, it|
      db_t = vdb(it)
      csv << ["# vdb[#{it}]:#{tname}"]
      db_t.keys.each.with_index{|dname, id|
        db_td = db_t[id]
        row = ["vdb[#{it},#{id}]:#{dname}"]
        db_td.keys.each.with_index{|cname, ic|
          db = db_td[ic]
          row << "#{cname}:#{value_hexlize db.value}"
        }
        csv << row
      }
    }
  end
)
