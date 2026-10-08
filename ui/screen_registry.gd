class_name ScreenRegistry
extends RefCounted
## Daftar seluruh layar (GDD 28.1) untuk ModalHost.


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
	host.register(&"lifecycle", func() -> UIScreen: return LifecyclePausedScreen.new())
	host.register(&"tutorial", func() -> UIScreen: return TutorialModal.new())
	host.register(&"tutorial_spotlight", func() -> UIScreen: return TutorialSpotlight.new())
	host.register(&"recipe_book", func() -> UIScreen: return RecipeBookScreen.new())
	host.register(&"slot_picker", func() -> UIScreen: return SlotPickerScreen.new())
	host.register(&"display_detail", func() -> UIScreen: return DisplayDetailScreen.new())
	host.register(&"customer_order", func() -> UIScreen: return CustomerOrderScreen.new())
	host.register(&"rotifood", func() -> UIScreen: return RotiFoodScreen.new())
	host.register(&"market", func() -> UIScreen: return MarketScreen.new())
	host.register(&"replace_picker", func() -> UIScreen: return ReplacePicker.new())
	host.register(&"staff", func() -> UIScreen: return StaffScreen.new())
	host.register(&"marketing", func() -> UIScreen: return MarketingScreen.new())
	host.register(&"decoration", func() -> UIScreen: return DecorationScreen.new())
	host.register(&"daily_summary", func() -> UIScreen: return DailySummaryScreen.new())
	host.register(&"bailout", func() -> UIScreen: return BailoutScreen.new())
	host.register(&"overflow", func() -> UIScreen: return OverflowScreen.new())
	host.register(&"debug", func() -> UIScreen: return DebugScreen.new())
