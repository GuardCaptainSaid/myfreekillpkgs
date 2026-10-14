local extension = Package:new("zhulin_qixian")

extension.extensionName = "AAA new sanguo"

extension:loadSkillSkelsByPath("./packages/AAA new sanguo/pkg/zhulin_qixian/skills")

Fk:loadTranslationTable{
  ["zhulin_qixian"] = "竹林七贤",
}

local ji_kang = General:new(extension, "ji_kang", "wei", 3, 3)
ji_kang:addSkills { "j_qingxian", "j_juexiang" }
ji_kang:addRelatedSkills { "j_jixian", "j_liexian", "j_rouxian", "j_hexian" }
Fk:loadTranslationTable{
  ["ji_kang"] = "嵇康",
  ["#ji_kang"] = "峻峰孤松",
  ["designer:ji_kang"] = "袁焉",
  ["illustrator:ji_kang"] = "豆包AI",
  ["cv:ji_kang"] = "佚名",

  ["~ji_kang"] = "广陵散绝，从此无弦……",
}

local xiang_xiu = General:new(extension, "xiang_xiu", "wei", 3, 3)
xiang_xiu:addSkills { "j_xiaoyao", "j_miaoxi", "j_sijiu" }
Fk:loadTranslationTable{
  ["xiang_xiu"] = "向秀",
  ["#xiang_xiu"] = "思旧鸣哀",
  ["designer:xiang_xiu"] = "袁焉",
  ["illustrator:xiang_xiu"] = "豆包AI",
  ["cv:xiang_xiu"] = "佚名",

  ["~xiang_xiu"] = "斯人已逝，庄周梦蝶……",
}

local wang_rong = General:new(extension, "wang_rong", "wei", 3, 3)
wang_rong:addSkills { "j_jianlin", "j_sixiao" }
Fk:loadTranslationTable{
  ["wang_rong"] = "王戎",
  ["#wang_rong"] = "善发谈端",
  ["designer:wang_rong"] = "袁焉",
  ["illustrator:wang_rong"] = "豆包AI",
  ["cv:wang_rong"] = "佚名",

  ["~wang_rong"] = "家道如此，吾亦无可奈何……",
}


local shan_tao = General:new(extension, "shan_tao", "wei", 4, 4)
shan_tao:addSkills { "j_lifu", "j_xunzun" }
Fk:loadTranslationTable{
  ["shan_tao"] = "山涛",
  ["#shan_tao"] = "钦才逊节",
  ["designer:shan_tao"] = "袁焉",
  ["illustrator:shan_tao"] = "豆包AI",
  ["cv:shan_tao"] = "佚名",

  ["~shan_tao"] = "玉山将颓，吾亦随之……",
}

local ruan_xian = General:new(extension, "ruan_xian", "wei", 3, 3)
ruan_xian:addSkills { "j_yilv", "j_shenjie" }
Fk:loadTranslationTable{
  ["ruan_xian"] = "阮咸",
  ["#ruan_xian"] = "琵音仲容",
  ["designer:ruan_xian"] = "袁焉",
  ["illustrator:ruan_xian"] = "豆包AI",
  ["cv:ruan_xian"] = "佚名",

  ["~ruan_xian"] = "琵琶声断，曲终人散……",
}

local liu_ling = General:new(extension, "liu_ling", "qun", 3, 3)
liu_ling:addSkills { "j_taowu", "j_jiukuang", "j_zuiukuang" }
Fk:loadTranslationTable{
  ["liu_ling"] = "刘伶",
  ["#liu_ling"] = "天地醉客",
  ["designer:liu_ling"] = "袁焉",
  ["illustrator:liu_ling"] = "豆包AI",
  ["cv:liu_ling"] = "佚名",

  ["~liu_ling"] = "死便埋我，醉且由他……",
}

return extension