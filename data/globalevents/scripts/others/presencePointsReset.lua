local function initLastResetStorage()
    local lastReset = getLastResetFromDB()
    if not lastReset then
        setLastResetToDB(os.time())
        print("Timer de god of destruction iniciado!")
    end
end

function onStartup()
	initLastResetStorage()
	return true
end