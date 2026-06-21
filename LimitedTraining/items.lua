return {
	PlaceObj('ModItemCode', {
		'name', "LimitedTraining",
		'CodeFileName', "Code/LimitedTraining.lua",
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "MaxTrainingPoints",
		'DisplayName', "Training Points Cap",
		'Help', "Maximum number of stat points a merc can gain from training in any single attribute.",
		'ChoiceList', {"10", "15", "20"},
		'DefaultValue', "10",
	}),
}
