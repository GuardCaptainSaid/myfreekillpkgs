local extension = Package:new("xinjun_celi")

extension.extensionName = "AAA new sanguo"

extension:loadSkillSkelsByPath("./packages/AAA new sanguo/pkg/xinjun_celi/skills")

-- 长江天堑：装备牌·宝物（仅由铸防转化获得，不进牌堆）
local j_changjiang = fk.CreateCard{
  name = "j_changjiang",
  type = Card.TypeEquip,
  sub_type = Card.SubtypeTreasure,
  equip_skill = "#j_changjiang_skill",
}
extension:loadCardSkels { j_changjiang }
Fk:loadTranslationTable{
  ["j_changjiang"] = "长江天堑",
  [":j_changjiang"] = "装备牌·宝物<br/>"..
    "<b>宝物技能</b>：当你需要使用/打出【闪】时，你可以进行判定，若结果为黑色，你视为使用/打出一张【闪】。",
}

Fk:loadTranslationTable{
  ["xinjun_celi"] = "新君册立",
  ["jun"] = "君",
}

local jun_caocao = General:new(extension, "jun_caocao", "jun", 4, 4)
jun_caocao:addSkills { "j_fengtian", "j_taochen", "j_dingye" }
Fk:loadTranslationTable{
  ["jun_caocao"] = "君曹操",
  ["#jun_caocao"] = "魏武帝",
  ["designer:jun_caocao"] = "袁焉",
  ["illustrator:jun_caocao"] = "豆包AI",
  ["cv:jun_caocao"] = "佚名",

  ["~jun_caocao"] = "孤的天下，终有尽时……",
}

local jun_liubei = General:new(extension, "jun_liubei", "jun", 4, 4)
jun_liubei:addSkills { "j_huangyu", "j_anjiang", "j_jiye" }
Fk:loadTranslationTable{
  ["jun_liubei"] = "君刘备",
  ["#jun_liubei"] = "汉昭烈帝",
  ["designer:jun_liubei"] = "袁焉",
  ["illustrator:jun_liubei"] = "豆包AI",
  ["cv:jun_liubei"] = "佚名",

  ["~jun_liubei"] = "汉室之业，终未能成……",
}

local jun_sunquan = General:new(extension, "jun_sunquan", "jun", 4, 4)
jun_sunquan:addSkills { "j_zhufang", "j_kuojing", "j_jianye" }
Fk:loadTranslationTable{
  ["jun_sunquan"] = "君孙权",
  ["#jun_sunquan"] = "吴大帝",
  ["designer:jun_sunquan"] = "袁焉",
  ["illustrator:jun_sunquan"] = "豆包AI",
  ["cv:jun_sunquan"] = "佚名",

  ["~jun_sunquan"] = "江东基业，赖卿等共守……",
}

local jun_yuanshu = General:new(extension, "jun_yuanshu", "jun", 4, 4)
jun_yuanshu:addSkills { "j_jiaochi", "j_zhenglue", "j_jianye2" }
Fk:loadTranslationTable{
  ["jun_yuanshu"] = "君袁术",
  ["#jun_yuanshu"] = "仲家帝",
  ["designer:jun_yuanshu"] = "袁焉",
  ["illustrator:jun_yuanshu"] = "豆包AI",
  ["cv:jun_yuanshu"] = "佚名",

  ["~jun_yuanshu"] = "吾之僭号，终成虚妄……",
}

local jun_gongsunzan = General:new(extension, "jun_gongsunzan", "jun", 4, 4)
jun_gongsunzan:addSkills { "j_tuji", "j_tuishou", "j_pozheng" }
Fk:loadTranslationTable{
  ["jun_gongsunzan"] = "君公孙瓒",
  ["#jun_gongsunzan"] = "白马将军",
  ["designer:jun_gongsunzan"] = "袁焉",
  ["illustrator:jun_gongsunzan"] = "豆包AI",
  ["cv:jun_gongsunzan"] = "佚名",

  ["~jun_gongsunzan"] = "白马义从，今随我尽……",
}

return extension