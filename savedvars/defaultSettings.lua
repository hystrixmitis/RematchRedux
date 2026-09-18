local _, rematchRedux = ... -- get addon namespace
local L = rematchRedux.localization
local C = rematchRedux.constants

-- Default settings; note that a nil default setting is discouraged since that means "undefined"; use false instead
-- This file is just the table definition for the default RematchRedux settings; the actual savedvar is in settings.lua, 
-- which also handles filling in missing keys with defaults

rematchRedux.defaultSettings = {
    LockPosition = false, -- Lock button in topleft
    CurrentLayout = C.DEFAULT_STANDALONE_LAYOUT, -- initial layout is standalone
    StandaloneLayout = C.DEFAULT_STANDALONE_LAYOUT, -- default layout for standalone window
    MaximizedLayout = C.DEFAULT_STANDALONE_LAYOUT, -- the last non-minimized standalone layout used
    JournalLayout = C.DEFAULT_JOURNAL_LAYOUT, -- default layout for journal window
    LastOpenLayout = C.DEFAULT_STANDALONE_LAYOUT, -- the last non-minimized layout used
    LastOpenJournal = false, -- whether the journal was open when RematchRedux last on screen
    PetSatchelIndex = 1, -- which set of toolbar buttons are shown from pet satchel
    UseTypeBar = false, -- whether the typebar in the petspanel is open
    TypeBarTab = C.TYPEBAR_TAB_TYPE, -- which typebar tab user is on
    Filters = {}, -- filters used in pet panel (setup in filters.lua)
    FavoriteFilters = {}, -- the filters saved from the Favorite Filters in the pet panel filter
    HiddenPets = {}, -- indexed by speciesID, true if speciesIDs should hide in the pet list
    ScriptFilters = {}, -- script filters saved from Script Filters in the pet panel filter
    PetMarkers = {}, -- pet markers for pet panel filter
    PetMarkerNames = {}, -- names for pet markers
    GroupOrder = {}, -- ordered list of team groupIDs in the order to display
    ExpandedGroups = {}, -- expanded groupIDs in teams panel
    ExpandedTargets = {}, -- expanded headerIDs in targets panel
    SpecialSlots = {}, -- for marking loadout slots as leveling, random or ignored
    LockNotesPosition = false, -- whether notes can be moved or resized
    NotesLeft = false, -- x position of notes relative to bottomleft of UIParent
    NotesBottom = false, -- y position of notes relative to bottomleft of UIParent
    NotesWidth = false, -- width of notes
    NotesHeight = false, -- height of notes
    PetNotes = {}, -- indexed by speciesID, notes for pets
    LevelingQueue = {}, -- ordered list of {petID,petTag} for leveling queue pets
    DefaultPreferences = {}, -- default leveling preferences that are always active
    PreferencesPaused = false, -- whether the preferences are paused for the leveling queue
    QueueActiveSort = false, -- whether leveling queue is actively sorted
    QueueSortOrder = C.QUEUE_SORT_ASC, -- order queue is actively sorted
    QueueSortInTeamsFirst = false, -- whether pets in teams sorted to top of queue
    QueueSortFavoritesFirst = false, -- whether favorites sorted to top of queue
    QueueSortRaresFirst = false, -- whether rares sorted to top of queue
    QueueSortAlpha = false, -- whether queue sorted alphabetically
    LastToastedPetID = false, -- petID of leveling pet that was last toasted for being slotted
    ExportIncludePreferences = false, -- whether to include preferences when exporting teams
    ExportIncludeNotes = false, -- whether to include notes when exporting teams
    ImportConflictOverwrite = false, -- whether to overwrite existing teams when teams share the same name
    LastSelectedGroup = "group:none", -- group last chosen in the import/save dialog
    MinimapButtonPosition = -162, -- position of minimap button in degrees
    BarChartCategory = C.BARCHART_IN_JOURNAL, -- which barchart category to show for pet collection
    BackupCount = 0, -- number of teams created since a backup was last offered
    WasShownOnLogout = false, -- true if the RematchRedux window was on screen during logout
    RankWinsByPercent = false, -- in PetSummary dialog, whether to rank teams by percent instead of wins
    MinimizePetSummary = true, -- whether to use PetSummaryMinimized dialog rather than PetSummary (maximized)
    DontDeleteOnCombine = false, -- Don't Delete Empty Group in CombineGroups dialog

    -- Interaction Options
    InteractOnTarget = C.INTERACT_NONE, -- On Target (dropdown)
    InteractOnSoftInteract = C.INTERACT_NONE, -- On Soft Target (dropdown)
    InteractOnMouseover = C.INTERACT_NONE, -- On Mouseover (dropdown)
    InteractAlways = false, -- Always Interact
    InteractAlwaysEvenLoaded = false, -- Even If Team Loaded (suboption of Always Interact)
    InteractPreferUninjured = false, -- Prefer Uninjured Teams
    InteractShowAfterLoad = false, -- Show Window After Loading
    InteractOnlyWhenInjured = false, -- Only When Any Pets Injured

    -- Standalone Window Options
    Anchor = "BOTTOMRIGHT",
    PanelTabAnchor = "BOTTOMRIGHT",
    LockWindow = false, -- Keep Window On Screen
    StayForBattle = false, -- Even For Pet Battles
    StayOnLogout = false, -- Even Across Sessions
    LockDrawer = false, -- Don't Minimize With ESC Key
    DontMinTabToggle = false, -- Don't Minimize With Panel Tabs
    PreferPetsTab = false, -- Show Pets Tab While Minimized
    LowerStrata = false, -- Lower Window Behind UI
    CustomScale = false, -- Use Custom Scale
    CustomScaleValue = 100, -- Use Custom Scale Value (in the grey button in options)
    ShowAfterBattle = false, -- Show Window After Battle
    ShowAfterPVEOnly = false, -- But Not After PVP Battle
    PreferMinimized = false, -- Prefer Minimized Window

    -- Appearance Options
    CompactPetList = false, -- Compact Pet List
    CompactTeamList = false, -- Compact Team List
    CompactTargetList = false, -- Compact Target List
    CompactQueueList = false, -- Compact Queue List
    HideLevelBubbles = false, -- Hide Level At Max Level
    HideRarityBorders = false, -- Hide Rarity Borders
    ColorPetNames = true, -- Color Pet Names By Rarity
    ColorTeamNames = true, -- Color Team Names By Group
    ColorTargetNames = true, -- Color Targets By Expansion
    DisplayUniqueTotal = false, -- Display Unique Pets Total
    ShowAbilityNumbers = false, -- Show Abiltiy Numbers
    ShowAbilityNumbersLoaded = false, -- On Loaded Abilities Too

    -- Badge Options
    HideTeamBadges = false, -- Hide Team Badges
    HideLevelingBadges = false, -- Hide Leveling Badges
    HideMarkerBadges = false, -- Hide Marker Badges
    HideTargetBadges = false, -- Hide Target Badges
    HidePreferenceBadges = false, -- Hide Preference Badges
    HideNotesBadges = false, -- HideNotesBadges

    -- Behavior Options
    CardBehavior = C.MOUSE_SPEED_NORMAL, -- Card Speed (dropdown)
    TooltipBehavior = C.MOUSE_SPEED_NORMAL, -- Tooltip Speed (dropdown)
    CollapseOnEsc = false, -- Collapse Lists With ESC Key
    MousewheelSpeed = C.MOUSE_SPEED_NORMAL, -- Mousewheel Speed

    -- Toolbar Options
    ReverseToolbar = false, -- Reverse Toolbar Buttons
    ToolbarDismiss = false, -- Hide Toolbar On Right Click
    SafariHatShine = false, -- Safari Hat Reminder
    AlwaysUsePetSatchel = false, -- Always Use Pet Satchel

    -- Miscellaneous Options
    UseDefaultJournal = false, -- Use Default Journal
    KeepCompanion = false, -- Keep Companion
    UseMinimapButton = false, -- Use Minimap Button
    NoSummonOnDblClick = false, -- No Summon On Double Click
    DisableShare = false, -- Disable Sharing

    -- Pet Filter Options
    StrongVsLevel = false, -- Use Level In Strong Vs Filter
    ResetFilters = false, -- Reset Filters On Login
    ResetSortWithFilters = false, -- Reset Sort With Filters
    ResetExceptSearch = false, -- Don't Reset Search With Filters
    SortByNickname = false, -- Sort By Chosen Name
    StickyNewPets = false, -- Sort New Pets To Top
    HideNonBattlePets = false, -- Hide Non-Battle Pets
    AllowHiddenPets = false, -- Allow Hidden Pets
    DontSortByRelevance = false, -- Don't Sort By Relevance
    ExportSimplePetList = false, -- Export Simple Pet List

    -- Breed Options
    BreedSource = false, -- Breed Source (dropdown)
    BreedFormat = C.BREED_FORMAT_LETTERS, -- Breed Format (dropdown)
    HideBreedsLists = false, -- Hide Breed In Lists
    HideBreedsLoadouts = false, -- Hide Breed In Pet Slots
    LargerBreedText = false, -- Larger Breed Text

    -- Pet Card Options
    PetCardBackground = "Expansion", -- Card Background
    PetCardFlipKey = "Alt", -- Flip Modifier Key
    PetCardCanPin = false, -- Allow Pet Cards To Be Pinned
    PetCardNoMouseoverFlip = false, -- Don't Flip On Mouseover
    PetCardShowExpansionStat = false, -- Show Expansion On Front
    ShowSpeciesID = false, -- Show Species ID
    PetCardCompactCollected = false, -- Always Use Collected Stat
    PetCardHidePossibleBreeds = false, -- Always Hide Possible Breeds
    PetCardAlwaysShowHPXPText = false, -- Always Show HP/XP Bar Text
    PetCardAlwaysShowHPBar = false, -- Always Show Health Bar
    BoringLoreFont = false, -- Alternate Lore Font
    PetCardInBattle = false, -- Use Pet Cards In Battle
    PetCardForLinks = false, -- Use Pet Cards For Links

    -- Team Options
    LoadHealthiest = false, -- Load Healthiest Pets
    LoadHealthiestAny = false, -- Ally Any Version
    LoadHealthiestAfterBattle = false, -- After Pet Battles Too
    ShowNewGroupTab = false, -- Show Create New Group Tab
    AlwaysTeamTabs = false, -- Always Show Team Tabs
    NeverTeamTabs = false, -- Never Show Team Tabs
    EchoTeamDrag = false, -- Display Where Teams Dragged
    EnableDrag = true, -- Enable Drag To Move Teams
    ClickToDrag = false, -- Require Click To Drag
    CombineGroupKey = "None", -- Group Combine Key
    ImportRememberOverride = false, -- Remember Override Import Option
    PrioritizeBreedOnImport = false, -- Prioritize Breed On Import

    -- Random Pet Options
    RandomPetRules = C.RANDOM_RULES_NORMAL, -- Random Pet Rules
    PickAggressiveCounters = false, -- Pick Aggressive Counters
    RandomAbilitiesToo = false, -- Random Abilities Too
    WarnWhenRandomNot25 = false, -- Warn For Pets Below Max Level

    -- Notes Options
    KeepNotesOnScreen = false, -- Keep Notes On Screen
    NotesNoEsc = false, -- Even When Escape Pressed
    ShowNotesOnLoad = false, -- Show Notes When Teams Load
    ShowNotesInBattle = false, -- Show Notes In Battle
    ShowNotesOnce = false, -- Only Once Per Team
    NotesFont = "GameFontHighlight", -- Notes Size
    HideNotesButtonInBattle = false, -- Hide Notes Button In Battle

    -- Team Win Record Options
    HideWinRecord = false, -- Hide Win Record Text
    AutoWinRecord = false, -- Auto Track Win Record
    AutoWinRecordPVPOnly = false, -- For PVP Battles Only
    AlternateWinRecord = false, -- Display Total Wins Instead

    -- Ability Tooltip Options
    AbilityBackground = "Icon", -- Ability Background
    ShowAbilityID = false, -- Show Ability IDs

    -- Confirmation Options
    DontConfirmHidePets = false, -- Don't Ask When Hiding Pets
    DontConfirmCaging = false, -- Don't Ask When Caging Pets
    DontConfirmDeleteTeams = false, -- Don't Ask When Deleting Teams
    DontConfirmDeleteNotes = false, -- Don't Ask When Deleting Notes
    DontConfirmFillQueue = false, -- Don't Ask When Filling Queue
    DontConfirmActiveSort = false, -- Don't Ask To Stop Active Sort
    DontConfirmRemoveQueue = false, -- Don't Ask For Queue Removal
    DontWarnMissing = false, -- Don't Warn About Missing Pets
    NoBackupReminder = false, -- Don't Remind About Backups

    -- Help Options
    HideMenuHelp = false, -- Hide Extra Help
    HideTooltips = false, -- Hide Descriptive Tooltips
    HideToolbarTooltips = false, -- Hide Toolbar Tooltips
    HideOptionTooltips = false, -- Hide Option Tooltips
    HideTruncatedTooltips = false, -- Hide Truncated Tooltips

    -- Leveling Queue Options
    ShowLoadedTeamPreferences = false, -- Show Extra Preferences Button
    QueueSortByNameToo = false, -- Sort Queue By Pet Name Too
    HidePetToast = false, -- Hide Leveling Pet Toast
    ShowFillQueueMore = false, -- Show Fill Queue More Option
    QueueSkipDead = false, -- Prefer Living Pets
    QueuePreferFullHP = false, -- And At Full Health
    QueueDoubleClick = false, -- Double Click To Send To Top
    QueueAutoLearn = false, -- Automatically Level New Pets
    QueueAutoLearnOnly = false, -- Only Pets Without One At 25
    QueueAutoLearnRare = false, -- Only Rare Pets
    QueueRandomWhenEmpty = false, -- Random Pet When Queue Empty
    QueueRandomMaxLevel = false, -- Pick Random Max Level
    QueueAutoImport = true, -- Add Imported Pets To Queue
}