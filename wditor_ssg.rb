require 'erb'
require 'ProcessMemory.rb'
require './lib/wditor_lib.rb'

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

WditString.proccess = memoryutil_startup

class String
  def ssg_escape
    gsub(/[\\\/:,=]/){|s| "\\#{s}" }
  end
end

ERB.new(<<EOS.encode('cp932'), nil, '%-').run
SSG for SpoilerAL ver 6.1
--------------------------------------------------------------------------------
[script]
[title]<%=
WditString.new(ptr(GAME_INFO)+4).to_s +
WditString.new(ptr(GAME_INFO)+0xE4).to_s
%>
[process]Game.exe
[distinction]五十音順=TODO:
[creator]TODO: あなたの名前
[maker]TODO: メーカー名
[note]wordwrap
<%=  Time.now.strftime "%F" %>: 自動生成
TODO: 説明などを書く
[/note]
[involve]List
% %w[SkillName ItemName WeaponName ArmorName 属性名 状態異常 EnemyName].zip([0, 2, 3, 4, 7, 8, 9]).each do |listname, type|
[group]<%= listname %>
%   udb(type).keys.each do |name|
<%= name %>
%   end
[/group]
% end
[/involve]
[group]AcrorName
% vdb(0).keys.each do |name|
<%= name %>
% end
[/group]
// End of List

// 以下がメイン部分
[involve]Game
[group]main
 [size]4
  [replace]_[:[:[:0x<%= VAR_DATABASE_BASE.to_s 16 %>:]+0x14+6*0x28:]+0x4+0*0x20:], Game->gold
  [subject]所持品:dir
   [subject]アイテム:dir
    [replace]_[:[:0x<%= VAR_DATABASE_BASE.to_s 16 %>:]+0x14+7*0x28:]+0x04, Game->item
   [back]
   [subject]武器:dir
    [replace]_[:[:0x<%= VAR_DATABASE_BASE.to_s 16 %>:]+0x14+8*0x28:]+0x04, Game->weapon
   [back]
   [subject]防具:dir
    [replace]_[:[:0x<%= VAR_DATABASE_BASE.to_s 16 %>:]+0x14+9*0x28:]+0x04, Game->armor
   [back]
  [back]
% #  [subject]ステータス（メニュー）:dir
% #   [repeat]Game->status_menu_rep, 12, 15, 1
% #  [back]
% #  [subject]ステータス（戦闘中）:dir
% #  //味方ステータス
% #  [repeat]Game->status_battle_rep_1, 0, 5, 1
% #  //敵側ステータス
% #  [repeat]Game->status_battle_rep_2, 10, 17, 1
% # [back]
 [/size]
[/group]

// 所持金変更
% # TODO: 通貨単位設定はudb[15][0][18]
[group]gold
 [subject]所持金　[　'+' _mem,0x00,4,num,-,%d '+'　]/所持金:calc,0x00,0,999999
[/group]

// 所持品
// 個数変更
% # TODO: udb(15)[0][0] で道具のメニュー名が取れる
% # TODO: udb(17)[0][0] でアイテムの最大所持数が取れる
[group]item
 [repeat]Game->each_item, 0, <%= udb(2).keys.size %>, 1
[/group]
[group]weapon
 [repeat]Game->each_weapon, 0, <%= udb(3).keys.size %>, 1
[/group]
[group]armor
 [repeat]Game->each_armor, 0, <%= udb(4).keys.size %>, 1
[/group]

[group]each_item
 [subject] [! @List->ItemName,  $Val !]/所持数:calc,_[:[.0x[!$Val*0x20!].]:],0,999,unsigned
[/group]
[group]each_weapon
 [subject] [! @List->WeaponName,$Val !]/所持数:calc,_[:[.0x[!$Val*0x20!].]:],0,999,unsigned
[/group]
[group]each_armor
 [subject] [! @List->ArmorName, $Val !]/所持数:calc,_[:[.0x[!$Val*0x20!].]:],0,999,unsigned
[/group]
[/involve]
// End of Game

[replace]0x00,Game->main
[/script]
EOS
