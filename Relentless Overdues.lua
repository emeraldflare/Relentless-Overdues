local Settings = {};
Settings.EmailName = GetSetting("EmailName");
Settings.StartDay = tonumber(GetSetting("StartDay"));
Settings.Time = GetSetting("Time");
Settings.Interval = GetSetting("Interval"):lower();
Settings.Exclusions = GetSetting("Exclusions");

function Init()
	RegisterSystemEventHandler("SystemTimerElapsed", "RelentlessOverdues");
end

function RelentlessOverdues()
	local curTime = os.date("%H%M"); -- Gets the current time in the format "hourminute." For example, 1:15 would be 0115.
	local curDay = os.date("%A"):lower(); -- Gets the current day of the week.
	
	if curTime == Settings.Time and Settings.Interval:match(curDay) then
		
		local curDate = JulianDate(os.date("%m/%d/%Y")); 
		
		local query = "SELECT Transactions.DueDate, Transactions.TransactionNumber FROM Transactions INNER JOIN Users ON Transactions.Username = Users.Username WHERE TransactionStatus = 'Checked Out to Customer'";
			
		if Settings.Exclusions:match("%w") then
			query = query .. " AND NVTGC NOT IN (" .. Settings.Exclusions .. ")";
		end
		
		local results = PullData(query);
		if not results then
			return;
		end

		for ct = 0, results.Rows.Count - 1 do
			local tn = results.Rows:get_Item(ct):get_Item("TransactionNumber");
			local dueDate = results.Rows:get_Item(ct):get_Item("DueDate");		
			dueDate = JulianDate(dueDate);
			
			if curDate >= (dueDate + Settings.StartDay) then
				ExecuteCommand("SendTransactionNotification", {tn, Settings.EmailName});
			end
		end
	end
end

function PullData(query) -- Used for SQL queries that will return more than one result.
	local connection = CreateManagedDatabaseConnection();
	function PullData2()
		connection.QueryString = query;
		connection:Connect();
		local results = connection:Execute();
		connection:Disconnect();
		connection:Dispose();
		
		return results;
	end
	
	local success, results = pcall(PullData2, query);
	if not success then
		LogDebug("Problem with SQL query: " .. query .. "\nError: " .. tostring(results));
		connection:Disconnect();
		connection:Dispose();
		return false;
	end
	
	return results;
end

function JulianDate(str) -- Converts dates to the Julian date. This makes it easier to do math, since Julian dates increment by one for each day regardless of the month or year.
	str = tostring(str);
	local month = tonumber(str:match("%d+"));
	local day = str:match("/%d+/");
	day = tonumber(day:match("%d+"));
	local year = tonumber(str:match("%d%d%d%d"));

	str = tonumber(tostring(((day - 32075 + 1461 * (year + 4800 + (month - 14) / 12) / 4 + 367 * (month - 2 -(month - 14) / 12 * 12) / 12 - 3 * ((year + 4900 + (month - 14) / 12) / 100) / 4))):match("%d%d%d%d%d%d%d"));
	
	return str;	
end

function OnError(errorArgs)
	LogDebug("Relentless Overdues had a problem! Error: " .. tostring(errorArgs));
end

