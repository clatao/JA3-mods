-- Limited Training mod for Jagged Alliance 3
-- author: claudio
--
-- In this mod, mercs can only gain a limited number of points from training in
-- in a given Attribute. Once they hit the cap, they won't be able to train
-- that Attribute further.

local MAX_TRAINING_POINTS = 10

-- Count stat points gained via training for a given stat.
-- Training gains use modifier ids with the format "StatTraining-{stat}-{session_id}-{ticks}",
-- each carrying add=1. Field Experience gains use "StatGain-..." and are not counted.
local function CountTrainingPoints(unitData, stat)
	local mod_list = unitData.modifications and unitData.modifications[stat]
	if not mod_list then return 0 end
	local prefix = "StatTraining-" .. stat .. "-"
	local count = 0
	for _, mod in ipairs(mod_list) do
		if mod.id and mod.id:sub(1, #prefix) == prefix then
			count = count + (mod.add or 0)
		end
	end
	return count
end

function OnMsg.DataLoaded()
	local op = SectorOperations and SectorOperations["TrainMercs"]
	if not op then return end

	-- Block students who've hit the training cap from being assigned as Students.
	local orig_FilterAvailable = op.FilterAvailable
	op.FilterAvailable = function(self, merc, profession)
		if profession == "Student" then
			local sector = merc:GetSector()
			local stat = sector and sector.training_stat
			if stat and CountTrainingPoints(merc, stat) >= MAX_TRAINING_POINTS then
				return false
			end
		end
		return orig_FilterAvailable(self, merc, profession)
	end

	-- Wrap Tick to enforce the training cap.
	--
	-- How progress updates flow in vanilla:
	-- With a teacher: teacher's Tick iterates over students and updates their
	--   stat_learning[stat].progress. The student's own Tick is a condition-only check.
	-- Solo (no teacher): student's own Tick updates their own progress.
	--
	-- In both cases we kick students who are at the cap before orig_Tick runs,
	-- so the teacher's inner loop (which re-fetches students via GetOperationProfessionals)
	-- won't process them. A second pass after orig_Tick catches anyone who just crossed the cap.
	local orig_Tick = op.Tick
	op.Tick = function(self, merc)
		local sector = merc:GetSector()
		local stat = sector and sector.training_stat
		if not stat then
			return orig_Tick(self, merc)
		end

		if merc.OperationProfession == "Teacher" then
			for _, student in ipairs(GetOperationProfessionals(sector.Id, self.id, "Student")) do
				if CountTrainingPoints(student, stat) >= MAX_TRAINING_POINTS then
					student:SetCurrentOperation("Idle")
				end
			end

			orig_Tick(self, merc)

			for _, student in ipairs(GetOperationProfessionals(sector.Id, self.id, "Student")) do
				if CountTrainingPoints(student, stat) >= MAX_TRAINING_POINTS then
					student:SetCurrentOperation("Idle")
				end
			end

		elseif merc.OperationProfession == "Student" then
			if CountTrainingPoints(merc, stat) >= MAX_TRAINING_POINTS then
				merc:SetCurrentOperation("Idle")
				return
			end
			orig_Tick(self, merc)
			-- Only solo students update their own progress in their Tick; with a teacher
			-- present the teacher's branch above already handles the post-tick check.
			local teachers = GetOperationProfessionals(sector.Id, self.id, "Teacher")
			if not next(teachers) and CountTrainingPoints(merc, stat) >= MAX_TRAINING_POINTS then
				merc:SetCurrentOperation("Idle")
			end
		else
			orig_Tick(self, merc)
		end
	end

end
