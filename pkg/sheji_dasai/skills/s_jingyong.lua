-- 超人强一号 · 竞勇（s_jingyong）
-- 每当你移去「盾」抵消伤害后，伤害来源可以选择一项：1.令你视为其使用决斗；2.令你摸两张牌。
local s_jingyong = fk.CreateSkill {
  name = "s_jingyong",
}

Fk:loadTranslationTable {
  ["s_jingyong"] = "竞勇",
  [":s_jingyong"] = "每当你移去「盾」抵消伤害后，伤害来源可以选择一项：1.令你视为其使用【决斗】；2.令你摸两张牌。",
  ["#s_jingyong-choose"] = "竞勇：伤害来源 %src 请选择一项",
  ["s_jingyong_duel"] = "令其视为你使用【决斗】",
  ["s_jingyong_draw"] = "令其摸两张牌",
  ["$s_jingyong1"] = "战意昂扬，敢与争锋！",
  ["$s_jingyong2"] = "此勇一振，谁与争雄！",
}

-- 由雄捍在移盾抵消伤害后联动调用
function s_jingyong:triggerFromShield(me, from)
  if me.dead or not from or from.dead then return end
  local room = me.room
  local choice = room:askToChoice(from, {
    choices = { "s_jingyong_duel", "s_jingyong_draw" },
    skill_name = s_jingyong.name,
    prompt = "#s_jingyong-choose:::"..me.id,
  })
  if choice == "s_jingyong_duel" then
    -- 令 me 视为 from 使用一张【决斗】（from 为使用者，me 为目标）
    local duel = room:printCard("duel", Card.NoSuit, 0)
    room:useCard{ from = from, tos = { me }, card = Fk:getCardById(duel), extraUse = true }
  else
    me:drawCards(2, s_jingyong.name)
  end
end

return s_jingyong