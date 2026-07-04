function Party:onJoin(player)
    if not player or not self then
        return true
    end
    
    local partyMembers = self:getMembers()
    local leader = self:getLeader()
    
    if leader then
        leader:sendExtendedOpcode(71)
    end
    
    if partyMembers then
        for _, member in ipairs(partyMembers) do
            member:sendExtendedOpcode(71)
        end
    end
    
    player:sendExtendedOpcode(71)
    return true
end

function Party:onLeave(player)
    if not player or not self then
        return true
    end
    
    local partyMembers = self:getMembers()
    local leader = self:getLeader()
    
    if leader then
		leader:sendExtendedOpcode(71)
    end
    
    if partyMembers then
        for _, member in ipairs(partyMembers) do
			member:sendExtendedOpcode(71)
        end
    end
    
	player:sendExtendedOpcode(71)
    
    return true
end


function Party:onDisband()
    return true
end

function Party:onpassPartyLeadership(player)
    local newLeader = self:getLeader()

    if newLeader then
        newLeader:sendExtendedOpcode(71)
    end

    local partyMembers = self:getMembers()
    if partyMembers then
        for _, member in ipairs(partyMembers) do
            member:sendExtendedOpcode(71)
        end
    end

    return true
end

function Party:onShareExperience(exp)
	local members = self:getMembers()
	table.insert(members, self:getLeader())

	local memberCount = #members
	if memberCount == 0 then
		return 0
	end

	local sharedExperienceMultiplier = 1.20
	local totalExp = exp * sharedExperienceMultiplier
	local expPerMember = math.floor(totalExp / memberCount)

	return expPerMember
end