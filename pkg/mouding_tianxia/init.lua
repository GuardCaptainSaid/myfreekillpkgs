local extension = Package:new("mouding_tianxia")

extension.extensionName = "AAA new sanguo"

extension:loadSkillSkelsByPath("./packages/AAA new sanguo/pkg/mouding_tianxia/skills")

Fk:loadTranslationTable{
  ["mouding_tianxia"] = "谋定天下",
}

General:new(extension, "mou_zhugeliang", "shu", 3, 3):addSkills { "m_jingyu", "m_buzhen", "m_qince" }
Fk:loadTranslationTable{
  ["mou_zhugeliang"] = "☆谋诸葛亮",
  ["#mou_zhugeliang"] = "北伐柱石",
  ["designer:mou_zhugeliang"] = "袁焉",
  ["illustrator:mou_zhugeliang"] = "豆包AI",
  ["cv:mou_zhugeliang"] = "佚名",

  ["~mou_zhugeliang"] = "出师未捷……身先死……长使英雄……泪满襟……",
}

return extension
