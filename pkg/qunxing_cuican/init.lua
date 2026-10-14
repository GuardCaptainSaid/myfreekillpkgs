local extension = Package:new("qunxing_cuican")

extension.extensionName = "AAA new sanguo"

extension:loadSkillSkelsByPath("./packages/AAA new sanguo/pkg/qunxing_cuican/skills")

Fk:loadTranslationTable{
  ["qunxing_cuican"] = "群星璀璨",
}

General:new(extension, "songxian_weixu", "qun", 4):addSkills {
  "j_daoge", "j_qishe", "j_yuji", "j_xianji", "j_kuiwei", "j_motu",
}
Fk:loadTranslationTable{
  ["songxian_weixu"] = "宋宪 & 魏续",
  ["#songxian_weixu"] = "叛戟双枭",
  ["designer:songxian_weixu"] = "袁焉",
  ["illustrator:songxian_weixu"] = "豆包AI",
  ["cv:songxian_weixu"] = "佚名",

  ["~songxian_weixu"] = "白门楼下，戟折人亡……",
}

local sp_caocao = General:new(extension, "sp_caocao", "wei", 3, 3)
sp_caocao:addSkills { "j_jiedao", "j_xiandao" }
sp_caocao:addRelatedSkills { "j_yifeng", "j_qiangxi" }
Fk:loadTranslationTable{
  ["sp_caocao"] = "SP曹操",
  ["#sp_caocao"] = "借刀刺董",
  ["designer:sp_caocao"] = "袁焉",
  ["illustrator:sp_caocao"] = "豆包AI",
  ["cv:sp_caocao"] = "佚名",

  ["~sp_caocao"] = "孟德愿献宝刀……为天下除此国贼……",
}

local xinchang_wangxiang = General:new(extension, "xinchang_wangxiang", "jin", 3, 3)
xinchang_wangxiang:addSkills { "j_jiance", "j_bingxin", "j_zhongxiao" }
Fk:loadTranslationTable{
  ["xinchang_wangxiang"] = "辛敞 & 王祥",
  ["#xinchang_wangxiang"] = "忠孝经纬",
  ["designer:xinchang_wangxiang"] = "袁焉",
  ["illustrator:xinchang_wangxiang"] = "豆包AI",
  ["cv:xinchang_wangxiang"] = "佚名",

  ["~xinchang_wangxiang"] = "忠孝两全，死而无憾……",
}

local jiangwei_zhonghui = General:new(extension, "jiangwei_zhonghui", "qun", 3, 3)
jiangwei_zhonghui:addSkills { "j_huaiyi", "j_fubing", "j_heli" }
jiangwei_zhonghui:addRelatedSkills { "j_gongmou", "j_yiyi" }
Fk:loadTranslationTable{
  ["jiangwei_zhonghui"] = "姜维 & 钟会",
  ["#jiangwei_zhonghui"] = "同心同德",
  ["designer:jiangwei_zhonghui"] = "袁焉",
  ["illustrator:jiangwei_zhonghui"] = "豆包AI",
  ["cv:jiangwei_zhonghui"] = "佚名",

  ["~jiangwei_zhonghui"] = "志同道合，生死与共……",
}

-- 姜维&钟会 皮肤
extension:addSkinPackage{
  content = {
    { enabled_generals = { "jiangwei_zhonghui" }, skins = { "jwxz_skin1", "jwxz_skin2" } },
  },
}
Fk:loadTranslationTable{
  ["$jwxz_skin1"] = "同契·昼",
  ["$jwxz_skin2"] = "同契·夜",
}

return extension