--
-- GameExtensionMenu
-- 
-- Main menu to change settings
-- 
-- @author:    	Xentro (Marcus@Xentro.se)
-- @website:	www.Xentro.se
-- 

GameExtensionMenu = {
	SETTINGS_PER_PAGE 	= 18,
	SETTINGS_PER_LINE 	= 6,

	-- 1 = Page element
	-- 2 = Setting elements
	-- 3 = Focus data
	--		1 = Index to first setting
	--		2 = Index to last setting
	PAGES_PAGE 			= 1,
	PAGES_SETTING 		= 2,
	PAGES_FOCUS 		= 3,

	PAGES_FOCUS_FIRST 	= 1,
	PAGES_FOCUS_LAST 	= 2,
	
	CONTROLS			= {
		-- Header
		"pageSelector",
		"pageMarkerTemplate",
		
		-- Body
		"rootPage",
		"toolTipBox",
			-- Settings
			"pageSettingsTemplate",
			"settingTemplate",
			-- Login
			"pageLogin",
		-- Footer
		"buttonsPanel",
		"menuButton",
	}
};


-- Menu stuff

function GameExtensionMenu:loadMenu(parent)
	parent:makeTextGlobal("PAGE_LOGIN");
	
	g_gui:loadProfiles(folderPaths.menu .. "GameExtensionProfiles.xml");
	g_gui:loadGui(folderPaths.menu .. "GameExtensionMenu.xml", "GameExtensionMenu", g_gameExtensionMenu);
	
	-- Add inputbinding, GameExtension.lua does the rest.
	parent.actionEventInfo["TOGGLE_GUI_SCREEN"] = {eventId = "", caller = g_gameExtensionMenu, callback = GameExtensionMenu.openMenu, triggerUp = false, triggerDown = true, triggerAlways = false, startActive = true, callbackState = nil, text = g_i18n:getText("TOGGLE_GUI_SCREEN"), textVisibility = false};
end;

function GameExtensionMenu:canOpenMenu()
	if (self.isOpen or not self.canOpen or g_currentMission.isSynchronizingWithPlayers) then
		return false;
	end;
	
	local allow = not g_currentMission.isTipTriggerInRange;
	
	-- ToDo: More checks are probably in place here.
	
	return allow;
end;

function GameExtensionMenu:openMenu()
	if self:canOpenMenu() then
		g_gui:showGui("GameExtensionMenu");
	end;
end;

function GameExtensionMenu:closeMenu()
	g_gui:showGui("");
end;


-- Input

function GameExtensionMenu:inputEvent(action, value, eventUsed)
	if self.inputDisableTime <= 0 then
		if action == InputAction.MENU_BACK then
			eventUsed = not self:closeMenu();
		end;
	end;

	eventUsed = GameExtensionMenu:superClass().inputEvent(self, action, value, eventUsed);

	return eventUsed;
end;

function GameExtensionMenu:onGuiSetupFinished()
	GameExtensionMenu:superClass().onGuiSetupFinished(self);
	
	-- Assign the buttons 
	local actions = {
		{inputAction = InputAction.MENU_BACK, callback = self.closeMenu, text = g_i18n:getText("button_back")} -- Back button
	};
	
	for i, v in ipairs(actions) do
		self.menuButton[i]:setVisible(true);
		self.menuButton[i]:setText(v.text);
		self.menuButton[i]:setInputAction(v.inputAction);
		self.menuButton[i].onClickCallback = v.callback;
	end;
end;

	
-- Main menu class

local GameExtensionMenu_mt = Class(GameExtensionMenu, ScreenElement);

function GameExtensionMenu:new(target)
	local self = ScreenElement:new(target, GameExtensionMenu_mt);
	
	self.canOpen = true;
	self.isLoaded = false;
	self.settingsAreInitialized = false;
	
	-- Store pages and settings before creating the elements
	self.pageData = {};
	self.pageDataIntToName = {};
	self.settingNameToIndex = {};
	
	self:addPage("client", g_i18n:getText("CLIENT_SETTING_PAGE"), false);
	self:addPage("server", g_i18n:getText("SERVER_SETTING_PAGE"), true);
	
	-- Page elements
	self.pages = {};
	self.pageMarkers = {};
	self.currentPage = 1;
	self.currentPageNum = 0;
	
	self.currentToolTip = {
		current 	= nil,
		selected 	= nil, -- Focused setting
		highlighted = nil  -- Highlighted setting, mouse hover 
	};

	self.menuButton = {};
	
	self:registerControls(GameExtensionMenu.CONTROLS);
	
	return self;
end;

function GameExtensionMenu:delete()
	GameExtensionMenu:superClass().delete(self);
	self:flushSettings();
	self:setIsLoaded(false);
end;

function GameExtensionMenu:update(dt)
	if self.currentToolTip.highlighted ~= nil then
		self:updateToolTip(self.currentToolTip.highlighted); -- Mouse over setting element
	elseif self.currentToolTip.selected ~= nil then
		self:updateToolTip(self.currentToolTip.selected);	 -- Selected setting element
	end;
end;

function GameExtensionMenu:onOpen()
	GameExtensionMenu:superClass().onOpen(self); -- This handles the mouse cursor
	
	if self:initializeSettings() then
		-- Update all setting elements since they could have changed
		for _, v in ipairs(self.pages) do
			for _, element in ipairs(v[GameExtensionMenu.PAGES_SETTING]) do
				self:setSettingValue(element);
			end;
		end;
	end;
	
	self:setPage(self.currentPage, false);
	g_depthOfFieldManager:setBlurState(true);
end;

function GameExtensionMenu:onClose()
	GameExtensionMenu:superClass().onClose(self);
	g_depthOfFieldManager:setBlurState(false);
end;


-- Creating Elements

function GameExtensionMenu:initializeSettings()
	if self.settingsAreInitialized then return true; end;
	
	log("DEBUG", "Menu - initializeSettings() ");
	
	-- Hide templates
	self.pageSettingsTemplate:setVisible(false);
	self.settingTemplate:setVisible(false);
	
	local pagesTitles = {};
	
	for i, name in pairs(self.pageDataIntToName) do
		local p = self.pageData[name];
		local numNeededPages = math.max(math.ceil(#p.settings / GameExtensionMenu.SETTINGS_PER_PAGE), 1);
		
		for k = 1, numNeededPages do
			table.insert(pagesTitles, p.pageName);
		end;
	
		self:createPageE(name, p.settings);
	end;
	
	if self.pageMarkerTemplate ~= nil then
		self.pageMarkerTemplate:setVisible(false); -- Need it on reload
		
		for i = 1, #pagesTitles, 1 do
			local marker = self.pageMarkerTemplate:clone(self.pageMarkerTemplate.parent);
			marker:setVisible(true);
			self.pageMarkers[i] = marker;
		end;
		
		self:centerElements(self.pageMarkers, self.pageMarkers[1].size[1] * 1);
	end;
	
	self.pageSelector:setTexts(pagesTitles);
	self:linkSettingsElements();
	self.settingsAreInitialized = true;
end;

function GameExtensionMenu:createPageE(pageName, items)
	local numSettings, countToPageLimit, lastItem, lastTableIndex = 0, 0, 0, {};
	
	-- Create an last index table, per page for focus
	for i, item in ipairs(items) do
		local s = self:getSettingType(item, item.variableName ~= nil);
		
		if g_gameExtension:getBlackListItem(s.name) == GameExtension.BL_STATE_NORMAL then
			numSettings = numSettings + 1;
			countToPageLimit = countToPageLimit + 1;
			lastItem = i;
			
			if countToPageLimit == GameExtensionMenu.SETTINGS_PER_PAGE then
				lastTableIndex[lastItem] = lastItem;
				countToPageLimit = 0;
			end;
		end;
	end;
	
	lastTableIndex[lastItem] = lastItem;
	
	log("DEBUG", "Menu: We have " .. numSettings .. " settings for page ( " .. pageName .. " )");
	
	-- Create page even if no settings
	if numSettings == 0 then
		self:clonePage();
		return;
	else
		local currentSetting, currentPageElement = 0;
		
		for i, item in ipairs(items) do
			local isCustomSetting = item.variableName ~= nil;
			local s = self:getSettingType(item, isCustomSetting);
			local newItem;
			
			if g_gameExtension:getBlackListItem(s.name) == GameExtension.BL_STATE_NORMAL then
				currentSetting = currentSetting + 1;
				
				-- Create new page
				if (currentSetting == 1 or currentSetting > GameExtensionMenu.SETTINGS_PER_PAGE) then
					currentSetting = 1;
					currentPageElement = self:clonePage();
				end;
				
				-- type.ModuleName.SettingName
				-- type.PageName.VariableName -- we don't use last one.
				if not isCustomSetting then
					local translation = Utils.getNoNil(s.isMod, g_i18n);
					newItem = self:createSetting(currentPageElement, s, s.inputType .. "." .. item.module .. "." .. s.name, translation:getText("toolTip_" .. s.name), translation:getText(s.name), s.value, isCustomSetting);
				else
					newItem = self:createSetting(currentPageElement, s, s.inputType .. "." .. pageName .. "." .. s.name, s.toolTip, s.shownName, s.parent[s.variableName], isCustomSetting, currentSetting);
				end;
				
				-- Update focus
				newItem.focusId = FocusManager.serveAutoFocusId(); -- "GE_autoId_" .. ((self.currentPageNum - 1) * GameExtensionMenu.SETTINGS_PER_PAGE) + currentSetting;
				FocusManager.guiFocusData["GameExtensionMenu"].idToElementMapping[newItem.focusId] = newItem;
				
				-- We are done add
				table.insert(self.pages[self.currentPageNum][GameExtensionMenu.PAGES_SETTING], newItem);
			
				if currentSetting == 1 then
					self.pages[self.currentPageNum][GameExtensionMenu.PAGES_FOCUS][GameExtensionMenu.PAGES_FOCUS_FIRST] = currentSetting;
				elseif lastTableIndex[i] ~= nil then
					self.pages[self.currentPageNum][GameExtensionMenu.PAGES_FOCUS][GameExtensionMenu.PAGES_FOCUS_LAST] = currentSetting;
					
					-- Create dummy, saves us the hazzle of needing to position the last item
					local newItem = self.settingTemplate:clone(currentPageElement.elements[1]):delete();
				end;
			end;
		end;
	end;
end;

function GameExtensionMenu:clonePage()
	self.currentPageNum = self.currentPageNum + 1;
	
	local clonedPage = self.pageSettingsTemplate:clone(self.rootPage);
	clonedPage:updateAbsolutePosition();
	-- clonedPage:setVisible(true);
	
	table.insert(self.pages, {clonedPage, {}, {0, 0}}); -- Page element, settings, first and last settingItem - See top for more
	
	return clonedPage;
end;

function GameExtensionMenu:linkSettingsElements()
	for i, v in ipairs(self.pages) do
		local settings = v[GameExtensionMenu.PAGES_SETTING];
		local focusFirst = v[GameExtensionMenu.PAGES_FOCUS][GameExtensionMenu.PAGES_FOCUS_FIRST];
		local focusLast = v[GameExtensionMenu.PAGES_FOCUS][GameExtensionMenu.PAGES_FOCUS_LAST];
		
		if #settings > 1 then
			for currentItem, element in ipairs(settings) do
				local top = currentItem - 1;
				local bottom = currentItem + 1;
				
				if currentItem == focusFirst then
					top = focusLast;
				end;
				
				if currentItem == focusLast then
					bottom = focusFirst;
				end;
				
				FocusManager:linkElements(element, FocusManager.TOP, settings[top]);
				FocusManager:linkElements(element, FocusManager.BOTTOM, settings[bottom]);
				
				-- log("DEBUG", "Menu: Page " .. self.pageDataIntToName[i] .. " - Linking setting " .. element.name .. " (" .. currentItem .. " / " .. element.focusId .. ") 	to setting " .. settings[top].name .. " (" .. top .. " / " .. settings[top].focusId .. ") 	and " .. settings[bottom].name .. " (".. bottom .. " / " .. settings[bottom].focusId .. ")");
			end;
		end;
	end;
	
	-- logTable(FocusManager.guiFocusData["GameExtensionMenu"].idToElementMapping, 0, "GameExtensionMenu.idToElementMapping.");
end;


-- Page Handeling

GameExtensionMenu.PAGE_FORCE = nil;
GameExtensionMenu.PAGE_LOGIN = -1;
GameExtensionMenu.PAGE_HELP  = -2;

function GameExtensionMenu:onClickPageSelection(currentPage)
	self:setPage(currentPage, false);
end;

function GameExtensionMenu:onPagePrevious()
	local page = self:checkPageCount(self.currentPage - 1, 0, self:getPageCount());
	self:setPage(page, true);
end;

function GameExtensionMenu:onPageNext()
	local page = self:checkPageCount(self.currentPage + 1, self:getPageCount() + 1, 1);
	self:setPage(page, true);
end;

function GameExtensionMenu:setPage(currentPage, buttonCall)
	-- if buttonCall and self.currentPage == currentPage then
	-- 	return; -- We dont want to update the page if its the same
	-- end;
	
	self.currentPage = currentPage;
	self.pageSelector:setState(currentPage);
	
	for i, marker in ipairs(self.pageMarkers) do
		if i == currentPage then
			marker:setOverlayState(GuiOverlay.STATE_SELECTED);
		else
			marker:setOverlayState(GuiOverlay.STATE_NORMAL);
		end;
	end;
	
	-- Now we can fool the system...
	local page = self:getPageByInt(currentPage);
	if not page.isAdminPage then
		if g_currentMission.missionDynamicInfo.isMultiplayer and not g_currentMission:getIsServer() then
			if not g_currentMission.isMasterUser then
				currentPage = GameExtensionMenu.PAGE_LOGIN; -- Login Page
			end;
		end;
	end;
	
	if GameExtensionMenu.PAGE_FORCE ~= nil and page.isAdminPage then
		currentPage = GameExtensionMenu.PAGE_FORCE;
	end;
	
	-- Handle the page switching here
	-- Set focus and overlay status of the 1th setting 
	-- Can we go negative on currentPage to implement an help page?
	
	for i, v in ipairs(self.pages) do
		v[GameExtensionMenu.PAGES_PAGE]:setVisible(i == currentPage);
	end;
	
	self.toolTipBox:setVisible(currentPage >= 1);
	self.pageLogin:setVisible(currentPage == GameExtensionMenu.PAGE_LOGIN);
	
	-- Focus
	if currentPage >= 1 then
		-- We could replace this to point towards the last selected setting.
		local element = self.pages[currentPage][GameExtensionMenu.PAGES_SETTING][GameExtensionMenu.PAGES_FOCUS_FIRST];
		
		FocusManager:setFocus(element);
		element:setOverlayState(GuiOverlay.STATE_FOCUSED); -- Update the focus state
	end;
end;


-- Settings Handeling

-- Type.ModuleName.SettingName
-- Type.PageName.VariableName 	- Custom
GameExtensionMenu.SPLIT_TYPE 	= 1;
GameExtensionMenu.SPLIT_MODULE 	= 2;
GameExtensionMenu.SPLIT_SETTING = 3;

function GameExtensionMenu:setSettingElement(value, element)
	local res = StringUtil.splitString(".", element.name);
	
	if not element.isCustomSetting then
		value = self:getSettingElementValue(res[GameExtensionMenu.SPLIT_TYPE], g_gameExtension:getSetting(res[GameExtensionMenu.SPLIT_MODULE], res[GameExtensionMenu.SPLIT_SETTING], true), value);
		g_gameExtension:setSetting(res[GameExtensionMenu.SPLIT_MODULE], res[GameExtensionMenu.SPLIT_SETTING], value);
		
	else
		local s = self:getSettingByInt(res[GameExtensionMenu.SPLIT_MODULE], element.settingId);

		if s ~= nil then
			value = self:getSettingElementValue(res[GameExtensionMenu.SPLIT_TYPE], s, value);
			
			if s.func ~= nil then
				s.func(s.parent, value);
			else
				log("NOTICE", "Menu: Your trying to set an variable trough the menu which aren't supported, you should make sure to add an function callback to setting " .. element.name);
			end;
		else
			log("ERROR", "Failed setSettingElement() - Setting id ( " .. tostring(element.settingId) .. " ), Page " .. tostring(res[GameExtensionMenu.SPLIT_MODULE]));
		end;
	end;
	
	-- log("DEBUG", "Menu: Changing value: " .. tostring(value) .. " 	for ( " .. element.name .. " )");
end;

function GameExtensionMenu:setSettingValue(element, value, settings)
	local valueType = Types.BOOL;
	
	if value == nil then
		local res = StringUtil.splitString(".", element.name);
		valueType = res[GameExtensionMenu.SPLIT_TYPE];
		
		if not element.isCustomSetting then
			settings = g_gameExtension:getSetting(res[GameExtensionMenu.SPLIT_MODULE], res[GameExtensionMenu.SPLIT_SETTING], true);
			value = settings.value;
		else
			settings = self.pageData[res[GameExtensionMenu.SPLIT_MODULE]].settings[element.settingId];
			value = settings.parent[settings.variableName];
			
			if value == nil then
				log("DEBUG", "Menu: setSettingValue() have an nil value for variable.");
			end;
		end;
	else
		valueType = settings.inputType;
	end;
	
	if valueType == Types.FLOAT or valueType == Types.INT then
		local row = 1;
		
		row = settings.options.rowToValue[value];
		element:setTexts(settings.options.rowToValue);
		element:setState(value, true);
	else
		local page = 1;
		if value then
			page = 2;
		end;
		
		element:setState(page, true);
	end;
	
	local lockState = g_gameExtension:getLockState(nil, nil, settings);
	element:setDisabled(lockState, false);
	
	-- log("DEBUG", "Menu: Updating setting element for ( " .. element.name .. " ) to ( " .. tostring(value) .. " ) - lockState " .. tostring(lockState));
end;


-- ToolTip

function GameExtensionMenu:updateHelpText(element)
	self.currentToolTip.selected = element;
end;

function GameExtensionMenu:onHighlightSetting(oldfunc, element)
	if oldFunc ~= nil then oldFunc(self); end;
	g_gameExtensionMenu.currentToolTip.highlighted = self;
end;

function GameExtensionMenu:onHighlightRemoveSetting(oldfunc, element)
	if oldFunc ~= nil then oldFunc(self); end;
	g_gameExtensionMenu.currentToolTip.highlighted = nil;
end;

function GameExtensionMenu:updateToolTip(current)
	if self.currentToolTip.current ~= nil then
		if self.currentToolTip.current ~= current then
			self:setToolTip(current);
		end;
	else
		self:setToolTip(current);
	end;
end;

function GameExtensionMenu:setToolTip(current)
	self.currentToolTip.current = current;

	if current.toolTip ~= nil then
		self.toolTipBox.elements[2]:setText(current.toolTip);
	end;
end;