local extension = Package:new("jiding_tianxia")

extension.extensionName = "AAA new sanguo"

extension:loadSkillSkelsByPath("./packages/AAA new sanguo/pkg/jiding_tianxia/skills")

local j_zicangxiangzeng = fk.CreateCard {
  name = "j_zicangxiangzeng",
  type = Card.TypeTrick,
  sub_type = Card.SubtypeDelayedTrick,
  skill = "j_zicangxiangzeng_skill",
}
extension:loadCardSkels { j_zicangxiangzeng }

Fk:loadTranslationTable{
  ["jiding_tianxia"] = "计定天下",

  ["j_zicangxiangzeng"] = "指仓相赠",
  [":j_zicangxiangzeng"] = "出牌阶段，对一名其他角色使用，将其置于其判定区。判定阶段，若判定结果与此牌花色相同或点数奇偶相同，将此牌置于其武将牌上，称为“囷”，然后重复此流程；否则你摸两张牌。“囷”可以视为手牌使用或打出，使用“囷”无次数限制。",
}

General:new(extension, "jiwangyi", "wei", 4, 4, General.Female):addSkills { "j_zhenlie", "j_miji" }
Fk:loadTranslationTable{
  ["jiwangyi"] = "计王异",
  ["#jiwangyi"] = "计慧贞妇",
  ["designer:jiwangyi"] = "袁焉",
  ["illustrator:jiwangyi"] = "袁焉",
  ["cv:jiwangyi"] = "佚名",

  ["~jiwangyi"] = "七纵之恩……来世……再报了……",
}

local ji_jiangwei = General:new(extension, "ji_jiangwei", "shu", 3, 4)
ji_jiangwei:addSkills { "j_jizhi2", "j_huitian", "j_liebei" }
ji_jiangwei:addRelatedSkills { "j_huaxin" }
Fk:loadTranslationTable{
  ["ji_jiangwei"] = "计姜维",
  ["#ji_jiangwei"] = "残躯化薪",
  ["designer:ji_jiangwei"] = "袁焉",
  ["illustrator:ji_jiangwei"] = "袁焉",
  ["cv:ji_jiangwei"] = "佚名",

  ["~ji_jiangwei"] = "丞相……姜维……尽力了……",
}

General:new(extension, "ji_xunyu", "wei", 3, 3):addSkills { "j_junmou", "j_zhixin", "j_jiesheng" }
Fk:loadTranslationTable{
  ["ji_xunyu"] = "计荀彧",
  ["#ji_xunyu"] = "大烈忠佐",
  ["designer:ji_xunyu"] = "袁焉",
  ["illustrator:ji_xunyu"] = "豆包AI",
  ["cv:ji_xunyu"] = "佚名",

  ["~ji_xunyu"] = "汉室……终无复兴之日……",
}

General:new(extension, "ji_luxun", "wu", 3, 3):addSkills { "j_lianying", "j_jizhi", "j_qianxun", "j_zhanhuo" }
Fk:loadTranslationTable{
  ["ji_luxun"] = "计陆逊",
  ["#ji_luxun"] = "红莲烈火",
  ["designer:ji_luxun"] = "袁焉",
  ["illustrator:ji_luxun"] = "袁焉",
  ["cv:ji_luxun"] = "佚名",

  ["~ji_luxun"] = "火……火……烧起来了……",
}

General:new(extension, "ji_guojia", "wei", 3, 4):addSkills { "j_zhicai", "j_chenglun" }
Fk:loadTranslationTable{
  ["ji_guojia"] = "计郭嘉",
  ["#ji_guojia"] = "天妒英才",
  ["designer:ji_guojia"] = "袁焉",
  ["illustrator:ji_guojia"] = "袁焉",
  ["cv:ji_guojia"] = "佚名",

  ["~ji_guojia"] = "天妒英才……奉孝……去矣……",
}

General:new(extension, "ji_jiaxu", "qun", 3, 3):addSkills { "j_lianpo", "j_mumou" }
Fk:loadTranslationTable{
  ["ji_jiaxu"] = "计贾诩",
  ["#ji_jiaxu"] = "极厄毒士",
  ["designer:ji_jiaxu"] = "袁焉",
  ["illustrator:ji_jiaxu"] = "豆包AI",
  ["cv:ji_jiaxu"] = "佚名",

  ["~ji_jiaxu"] = "算尽苍生……终算不过天命……",
}

General:new(extension, "ji_wangyun", "qun", 3, 4):addSkills { "j_jianji", "j_jianmou", "j_jianzhi" }
Fk:loadTranslationTable{
  ["ji_wangyun"] = "计王允",
  ["#ji_wangyun"] = "妙计连环",
  ["designer:ji_wangyun"] = "袁焉",
  ["illustrator:ji_wangyun"] = "豆包AI",
  ["cv:ji_wangyun"] = "佚名",

  ["~ji_wangyun"] = "连环之策……终是算漏了一着……",
}

local ji_lusu = General:new(extension, "ji_lusu", "wu", 3, 4)
ji_lusu:addSkills { "j_shezeng", "j_dizhi", "j_xiemeng" }
ji_lusu:addRelatedSkills { "j_qun" }
Fk:loadTranslationTable{
  ["ji_lusu"] = "计鲁肃",
  ["#ji_lusu"] = "慷慨解囊",
  ["designer:ji_lusu"] = "袁焉",
  ["illustrator:ji_lusu"] = "袁焉",
  ["cv:ji_lusu"] = "佚名",

  ["~ji_lusu"] = "君子之交……淡如水……",
}

General:new(extension, "ji_sunce", "wu", 3, 4):addSkills { "j_zhixi", "j_bazheng" }
Fk:loadTranslationTable{
  ["ji_sunce"] = "计孙策",
  ["#ji_sunce"] = "坐断东南",
  ["designer:ji_sunce"] = "袁焉",
  ["illustrator:ji_sunce"] = "袁焉",
  ["cv:ji_sunce"] = "佚名",

  ["~ji_sunce"] = "此恨未雪……江东基业……交与仲谋了……",
}

General:new(extension, "ji_chenzhi", "shu", 3, 3):addSkills { "j_hengzheng", "j_zishi" }
Fk:loadTranslationTable{
  ["ji_chenzhi"] = "计陈祗",
  ["#ji_chenzhi"] = "权枢斡旋",
  ["designer:ji_chenzhi"] = "袁焉",
  ["illustrator:ji_chenzhi"] = "豆包AI",
  ["cv:ji_chenzhi"] = "佚名",

  ["~ji_chenzhi"] = "陈祗死不足惜……只恨国事难回……",
}

General:new(extension, "ji_zhugeliang", "qun", 3, 3):addSkills { "j_yanshi", "j_zaoshi", "j_yinju", "j_sangu", "j_zhiji" }
Fk:loadTranslationTable{
  ["ji_zhugeliang"] = "计诸葛亮",
  ["#ji_zhugeliang"] = "龙卧于野",
  ["designer:ji_zhugeliang"] = "袁焉",
  ["illustrator:ji_zhugeliang"] = "豆包AI",
  ["cv:ji_zhugeliang"] = "佚名",

  ["~ji_zhugeliang"] = "出师未捷身先死，长使英雄泪满襟……",
}

return extension
