--[[
	Script: autoSpellAvoider v0.1
	Author: SurfaceS Modified - Barasia script based
	
	required libs : 		spellList,  common
	required sprites : 		-
	exposed variables : 	-
	
	v0.1		initial release
	v0.2		BoL Studio Version
]]

require "AllClass"
require "spellList"

do
	local spellAvoider = {
		--[[         Config          ]]
		globalspacing = 250,														-- default spacing between circle in line
		colors = {4294967295, 4294967295, 0xFFFFFF00, 4294967295, 0xFF00FF00},		-- color for skill type (indexed)
		dodgeSkillShot = false,														-- default autoDodge (true/false)
		drawSkillShot = true,														-- default draw Skill (true/false)
		dodgeSkillShotHK = 74, 														-- autoDodge toogle key (jJj by default)
		useWorldToScreen = false,
		--[[     GLOBALS     ]]--
		spellArray = {},
		spellArrayCount = 0,
		moveTo = {},
	}
	
	--[[         Code          ]]
	function OnLoad()
		for i = 1, heroManager.iCount, 1 do 
			local hero = heroManager:getHero(i)
			if hero ~= nil and hero.team ~= player.team then
				for i, spell in pairs(spellList) do
					if string.lower(spell.charName) == string.lower(hero.charName) or (spell.charName == "" and (string.find(hero:GetSpellData(SUMMONER_1).name..hero:GetSpellData(SUMMONER_2).name, i))) then
						spellAvoider.spellArrayCount = spellAvoider.spellArrayCount + 1
						spellAvoider.spellArray[i] = spellList[i]
						spellAvoider.spellArray[i].color = spellAvoider.colors[spellAvoider.spellArray[i].spellType]
						spellAvoider.spellArray[i].shot = false
						spellAvoider.spellArray[i].lastshot = 0
						spellAvoider.spellArray[i].skillshotpoint = {}
					end
				end
			end
		end
		-- unload spellList Lib as it's not needed anymore
		spellList = nil
		-- unload spellAvoider if no spell founded
		if spellAvoider.spellArrayCount == 0 then
			spellAvoider = nil
		else
			function spellAvoider.setGlobalspacing(up)
				local value = (up and 50 or -50)
				spellAvoider.globalspacing = math.max(100, spellAvoider.globalspacing + value)
				PrintChat("Skillshot Spacing : "..spellAvoider.globalspacing)
			end
			function spellAvoider.setDodgeSkillShot(value)
				if spellAvoider.dodgeSkillShot ~= value then
					spellAvoider.dodgeSkillShot = value
					PrintChat("AutoDodge "..(spellAvoider.dodgeSkillShot and "ON" or "OFF").." !")
				end
			end
			function spellAvoider.setDrawSkillShot(value)
				if spellAvoider.drawSkillShot ~= value then
					spellAvoider.drawSkillShot = value
					PrintChat("Draw Skillshot "..(spellAvoider.drawSkillShot and "ON" or "OFF").." !")
				end
			end
			
			function spellAvoider.calculateLinepass(pos1, pos2, maxDist)
				local spellVector = Vector(pos2) - pos1
				spellVector = spellVector / spellVector:len() * maxDist
				local line = {}
				local steps = math.round(maxDist/spellAvoider.globalspacing)
				for i = 0, steps do
					table.insert(line, spellVector / steps * i + pos1)
				end
				return line
			end

			function spellAvoider.calculateLinepoint(pos1, pos2, maxDist)
				local spellVector = Vector(pos2) - pos1
				if spellVector:len() > maxDist then
					spellVector = spellVector / spellVector:len() * maxDist
				end
				local line = {}
				local steps = math.round(maxDist/spellAvoider.globalspacing)
				for i = 0, steps do
					table.insert(line, spellVector / steps * i + pos1)
				end
				return line
			end

			function spellAvoider.calculateLineaoe(pos1, pos2, maxDist)
				return {Vector(pos2)}
			end

			function spellAvoider.calculateLineaoe2(pos1, pos2, maxDist)
				local spellVector = Vector(pos2) - pos1
				if spellVector:len() > maxDist then
					spellVector = spellVector / spellVector:len() * maxDist
					return {spellVector + pos1}
				else
					return {Vector(pos2)}
				end
			end

			function spellAvoider.dodgeAOE(pos1, pos2, radius)
				local distancePos2 = GetDistance2D(player, pos2) 
				if distancePos2 < radius then
					spellAvoider.moveTo.x = pos2.x + ((radius+50)/distancePos2)*(player.x-pos2.x)
					spellAvoider.moveTo.z = pos2.z + ((radius+50)/distancePos2)*(player.z-pos2.z)
					if spellAvoider.dodgeSkillShot then
						player:MoveTo(spellAvoider.moveTo.x,spellAvoider.moveTo.z)
					end
				end
			end

			function spellAvoider.dodgeLinePoint(pos1, pos2, radius)
				local distancePos1 = GetDistance2D(player, pos1)
				local distancePos2 = GetDistance2D(player, pos2)
				local distancePos1Pos2 = GetDistance2D(pos1, pos2)
				local perpendicular = (math.floor((math.abs((pos2.x-pos1.x)*(pos1.z-player.z)-(pos1.x-player.x)*(pos2.z-pos1.z)))/distancePos1Pos2))
				if perpendicular < radius and distancePos2 < distancePos1Pos2 and distancePos1 < distancePos1Pos2 then
					local k = ((pos2.z-pos1.z)*(player.x-pos1.x) - (pos2.x-pos1.x)*(player.z-pos1.z)) / distancePos1Pos2
					local pos3 = {}
					pos3.x = player.x - k * (pos2.z-pos1.z)
					pos3.z = player.z + k * (pos2.x-pos1.x)
					local distancePos3 = GetDistance2D(player, pos3)
					spellAvoider.moveTo.x = pos3.x + ((radius+50)/distancePos3)*(player.x-pos3.x)
					spellAvoider.moveTo.z = pos3.z + ((radius+50)/distancePos3)*(player.z-pos3.z)
					if spellAvoider.dodgeSkillShot then
						player:MoveTo(spellAvoider.moveTo.x,spellAvoider.moveTo.z)
					end
				end
			end

			function spellAvoider.dodgeLinePass(pos1, pos2, radius, maxDist)
				local distancePos1 = GetDistance2D(player, pos1)
				local distancePos1Pos2 = GetDistance2D(pos1, pos2)
				local pos3 = {}
				pos3.x = pos1.x + (maxDist)/distancePos1Pos2*(pos2.x-pos1.x)
				pos3.z = pos1.z + (maxDist)/distancePos1Pos2*(pos2.z-pos1.z)
				local distancePos3 = GetDistance2D(player, pos3)
				local distancePos1Pos3 = GetDistance2D(pos1, pos3)
				local perpendicular = (math.floor((math.abs((pos3.x-pos1.x)*(pos1.z-player.z)-(pos1.x-player.x)*(pos3.z-pos1.z)))/distancePos1Pos3))
				if perpendicular < radius and distancePos3 < distancePos1Pos3 and distancePos1 < distancePos1Pos3 then
					local k = ((pos3.z-pos1.z)*(player.x-pos1.x) - (pos3.x-pos1.x)*(player.z-pos1.z)) / ((pos3.z-pos1.z)^2 + (pos3.x-pos1.x)^2)
					local pos4 = {}
					pos4.x = player.x - k * (pos3.z-pos1.z)
					pos4.z = player.z + k * (pos3.x-pos1.x)
					local distancePos4 = GetDistance2D(player, pos4)
					spellAvoider.moveTo.x = pos4.x + ((radius+50)/distancePos4)*(player.x-pos4.x)
					spellAvoider.moveTo.z = pos4.z + ((radius+50)/distancePos4)*(player.z-pos4.z)
					if spellAvoider.dodgeSkillShot then
						player:MoveTo(spellAvoider.moveTo.x,spellAvoider.moveTo.z)
					end
				end
			end
			
			function OnProcessSpell(object,spell)
				if player.dead == true then return end
				if object~=nil and object.team~=player.team and spellAvoider.spellArray[spell.name] ~= nil and GetDistance2D(player, object) < spellAvoider.spellArray[spell.name].range + spellAvoider.spellArray[spell.name].size + 500 then
					spellAvoider.spellArray[spell.name].shot = true
					spellAvoider.spellArray[spell.name].lastshot = GetTickCount()
					if spellAvoider.spellArray[spell.name].spellType == 1 then
						spellAvoider.spellArray[spell.name].skillshotpoint = spellAvoider.calculateLinepass(spell.startPos, spell.endPos, spellAvoider.spellArray[spell.name].range)
						spellAvoider.dodgeLinePass(spell.startPos, spell.endPos, spellAvoider.spellArray[spell.name].size, spellAvoider.spellArray[spell.name].range)
					elseif spellAvoider.spellArray[spell.name].spellType == 2 then
						spellAvoider.spellArray[spell.name].skillshotpoint = spellAvoider.calculateLinepoint(spell.startPos, spell.endPos, spellAvoider.spellArray[spell.name].range)
						spellAvoider.dodgeLinePoint(spell.startPos, spell.endPos, spellAvoider.spellArray[spell.name].size)
					elseif spellAvoider.spellArray[spell.name].spellType == 3 then
						spellAvoider.spellArray[spell.name].skillshotpoint = spellAvoider.calculateLineaoe(spell.startPos, spell.endPos, spellAvoider.spellArray[spell.name].range)
						if spell.name ~= "SummonerClairvoyance" then
							spellAvoider.dodgeAOE(spell.startPos, spell.endPos, spellAvoider.spellArray[spell.name].size)
						end
					elseif spellAvoider.spellArray[spell.name].spellType == 4 then
						spellAvoider.spellArray[spell.name].skillshotpoint = spellAvoider.calculateLinepass(spell.startPos, spell.endPos, 1000, spellAvoider.spellArray[spell.name].range)
						spellAvoider.dodgeLinePass(spell.startPos, spell.endPos, spellAvoider.spellArray[spell.name].size, spellAvoider.spellArray[spell.name].range)
					elseif spellAvoider.spellArray[spell.name].spellType == 5 then
						spellAvoider.spellArray[spell.name].skillshotpoint = spellAvoider.calculateLineaoe2(spell.startPos, spell.endPos, spellAvoider.spellArray[spell.name].range)
						spellAvoider.dodgeAOE(spell.startPos, spell.endPos, spellAvoider.spellArray[spell.name].size)
					end
				end
			end
			
			function OnDraw()
				for i, spell in pairs(spellAvoider.spellArray) do
					if spell.shot then
						--when WorldToScreen work, use DrawLine
						for j, point in pairs(spell.skillshotpoint) do
							DrawCircle(point.x, point.y, point.z, spell.size, spell.color)
						end
					end
				end
			end
			
			function OnTick()
				if IsKeyPressed(spellAvoider.dodgeSkillShotHK) then spellAvoider.setDodgeSkillShot(not spellAvoider.dodgeSkillShot) end
				local tick = GetTickCount()
				for i, spell in pairs(spellAvoider.spellArray) do
					if spell.shot and spell.lastshot < tick - spell.duration then
						spell.shot = false
						spell.skillshotpoint = {}
						spellAvoider.moveTo = {}
					end
				end
			end
		end
	end
end