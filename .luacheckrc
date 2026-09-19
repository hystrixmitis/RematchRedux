std = "lua51"
max_line_length = false

ignore = { "212/self" }  -- unused 'self' argument — expected constantly in this mixin-heavy codebase

globals = {
    "RematchRedux",
}

read_globals = {
    -- Blizzard C_* namespace tables actually used in this codebase
    "C_AddOns",
    "C_BattleNet",
    "C_ChatInfo",
    "C_Item",
    "C_Map",
    "C_PetBattles",
    "C_PetJournal",
    "C_QuestLog",
    "C_Spell",
    "C_TaskQuest",
    "C_Timer",
    "C_UnitAuras"
}