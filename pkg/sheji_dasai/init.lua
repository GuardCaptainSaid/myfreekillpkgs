local extension = Package:new("sheji_dasai")

extension.extensionName = "AAA new sanguo"

extension:loadSkillSkelsByPath("./packages/AAA new sanguo/pkg/sheji_dasai/skills")

Fk:loadTranslationTable{
  ["sheji_dasai"] = "设计大赛优秀作品",
}

local shushao_1 = General:new(extension, "shushao_1", "qun", 3, 3)
shushao_1:addSkills { "s_shushao_sanji", "s_shushao_zhengfu" }
Fk:loadTranslationTable{
  ["shushao_1"] = "舒邵一号",
  ["#shushao_1"] = "散粮济荒",
  ["designer:shushao_1"] = "卫队长赛伊得",
  ["illustrator:shushao_1"] = "卫队长赛伊得",
  ["cv:shushao_1"] = "佚名",

  ["~shushao_1"] = "仓廪已空，吾心难安……",
}

local shushao_2 = General:new(extension, "shushao_2", "qun", 3, 3)
shushao_2:addSkills { "s_sanlin", "s_zhengyi" }
Fk:loadTranslationTable{
  ["shushao_2"] = "舒邵二号",
  ["#shushao_2"] = "兄弟争死",
  ["designer:shushao_2"] = "卫队长赛伊得",
  ["illustrator:shushao_2"] = "卫队长赛伊得",
  ["cv:shushao_2"] = "佚名",

  ["~shushao_2"] = "廪散义存，死亦无憾……",
}

local shushao_3 = General:new(extension, "shushao_3", "qun", 3, 3)
shushao_3:addSkills { "s_renzhui", "s_zhengxing", "s_sanlin2" }
Fk:loadTranslationTable{
  ["shushao_3"] = "舒邵三号",
  ["#shushao_3"] = "廪刑锥义",
  ["designer:shushao_3"] = "若雪里面软",
  ["illustrator:shushao_3"] = "佚名",
  ["cv:shushao_3"] = "佚名",

  ["~shushao_3"] = "锥义已尽，廪散当归……",
}

local shushao_4 = General:new(extension, "shushao_4", "qun", 4, 4)
shushao_4:addSkills { "s_sanliang4", "s_ningji", "s_tutan" }
Fk:loadTranslationTable{
  ["shushao_4"] = "舒邵四号",
  ["#shushao_4"] = "积粮宁己",
  ["designer:shushao_4"] = "情意化剑",
  ["illustrator:shushao_4"] = "佚名",
  ["cv:shushao_4"] = "佚名",

  ["~shushao_4"] = "粮尽涂炭，吾其归矣……",
}

local shushao_5 = General:new(extension, "shushao_5", "qun", 4, 4)
shushao_5:addSkills { "s_zhengyi2", "s_sanliang" }
Fk:loadTranslationTable{
  ["shushao_5"] = "舒邵五号",
  ["#shushao_5"] = "争义散粮",
  ["designer:shushao_5"] = "山水之間見你",
  ["illustrator:shushao_5"] = "佚名",
  ["cv:shushao_5"] = "佚名",

  ["~shushao_5"] = "粮散义存，此生无憾……",
}

local shushao_6 = General:new(extension, "shushao_6", "qun", 4, 4)
shushao_6:addSkills { "s_zhenmin", "s_huoshe" }
Fk:loadTranslationTable{
  ["shushao_6"] = "舒邵六号",
  ["#shushao_6"] = "赈民获赦",
  ["designer:shushao_6"] = "canie",
  ["illustrator:shushao_6"] = "佚名",
  ["cv:shushao_6"] = "佚名",

  ["~shushao_6"] = "赈济已尽，天赦难期……",
}

local chaorenqiang_1 = General:new(extension, "chaorenqiang_1", "qun", 4, 3)
chaorenqiang_1:addSkills { "s_xionghan", "s_jingyong" }
Fk:loadTranslationTable{
  ["chaorenqiang_1"] = "超人强一号",
  ["#chaorenqiang_1"] = "盾勇争锋",
  ["designer:chaorenqiang_1"] = "卫队长赛伊得",
  ["illustrator:chaorenqiang_1"] = "佚名",
  ["cv:chaorenqiang_1"] = "佚名",

  ["~chaorenqiang_1"] = "盾坚犹在，勇魄难消……",
}

local chaorenqiang_2 = General:new(extension, "chaorenqiang_2", "qun", 4, 4)
chaorenqiang_2:addSkills { "s_jianti", "s_mengtu" }
Fk:loadTranslationTable{
  ["chaorenqiang_2"] = "超人强二号",
  ["#chaorenqiang_2"] = "健体猛突",
  ["designer:chaorenqiang_2"] = "最亮的小星星",
  ["illustrator:chaorenqiang_2"] = "佚名",
  ["cv:chaorenqiang_2"] = "佚名",

  ["~chaorenqiang_2"] = "力竭身疲，犹自奋战……",
}

local kebineng_1 = General:new(extension, "kebineng_1", "qun", 5, 3)
kebineng_1:addSkills { "s_fanyi", "s_jianghuo" }
Fk:loadTranslationTable{
  ["kebineng_1"] = "轲比能一号",
  ["#kebineng_1"] = "藩异疆祸",
  ["designer:kebineng_1"] = "佚名",
  ["illustrator:kebineng_1"] = "佚名",
  ["cv:kebineng_1"] = "佚名",

  ["~kebineng_1"] = "北疆未靖，此心难安……",
}

local kebineng_2 = General:new(extension, "kebineng_2", "qun", 4, 4)
kebineng_2:addSkills { "s_yuebian", "s_koubian2", "s_muhan" }
Fk:loadTranslationTable{
  ["kebineng_2"] = "轲比能二号",
  ["#kebineng_2"] = "狄骑",
  ["designer:kebineng_2"] = "四世三公老袁",
  ["illustrator:kebineng_2"] = "佚名",
  ["cv:kebineng_2"] = "佚名",

  ["~kebineng_2"] = "狄骑北望，胡尘蔽日……",
}

local baosanniang_1 = General:new(extension, "baosanniang_1", "shu", 3, 3)
baosanniang_1:addSkills { "s_wujiang", "s_ximin", "s_shouwu" }
Fk:loadTranslationTable{
  ["baosanniang_1"] = "鲍三娘一号",
  ["designer:baosanniang_1"] = "卫队长赛伊得",
  ["illustrator:baosanniang_1"] = "佚名",
  ["cv:baosanniang_1"] = "佚名",

  ["~baosanniang_1"] = "关山万里，巾帼不让须眉……",
}

return extension