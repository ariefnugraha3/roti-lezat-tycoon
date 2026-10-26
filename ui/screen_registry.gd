class_name ScreenRegistry
extends RefCounted
## Daftar seluruh layar (GDD idle 12.3; v3.1 28.1) untuk ModalHost.


static func register_all(host: ModalHost) -> void:
	host.register(&"main_menu", func() -> UIScreen: return MainMenuScreen.new())
	host.register(&"profiles", func() -> UIScreen: return ProfileScreen.new())
	host.register(&"new_game", func() -> UIScreen: return NewGameScreen.new())
	host.register(&"error", func() -> UIScreen: return ErrorScreen.new())
	host.register(&"confirm", func() -> UIScreen: return ConfirmDialog.new())
	host.register(&"settings", func() -> UIScreen: return SettingsScreen.new())
	host.register(&"credits", func() -> UIScreen: return CreditsScreen.new())
	host.register(&"help", func() -> UIScreen: return HelpScreen.new())
	host.register(&"stats", func() -> UIScreen: return StatsScreen.new())
	host.register(&"pause", func() -> UIScreen: return PauseScreen.new())
	host.register(&"tutorial", func() -> UIScreen: return TutorialModal.new())
	host.register(&"tutorial_spotlight", func() -> UIScreen: return TutorialSpotlight.new())
	host.register(&"upgrades", func() -> UIScreen: return UpgradesScreen.new())
	host.register(&"menu", func() -> UIScreen: return MenuScreen.new())
	host.register(&"shop", func() -> UIScreen: return ShopScreen.new())
	host.register(&"upgrade_card", func() -> UIScreen: return UpgradeCard.new())
	host.register(&"staff", func() -> UIScreen: return StaffScreen.new())
	host.register(&"decoration", func() -> UIScreen: return DecorationScreen.new())
	host.register(&"overflow", func() -> UIScreen: return OverflowScreen.new())
	host.register(&"welcome_back", func() -> UIScreen: return WelcomeBackScreen.new())
	host.register(&"debug", func() -> UIScreen: return DebugScreen.new())
