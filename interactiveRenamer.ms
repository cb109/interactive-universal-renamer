fileIn "nameplates.ms"

-- Global accessor for script. Must be defined prior to the struct to be used by callbacks!
global gInteractiveRenamer 

struct InteractiveRenamer
(
	version = 2.0,
	self,
	factory,
	nameplates, -- All nameplates that fit the mode and source
	nameplatesInList, -- Nameplates that match the filter and are sorted -> renaming is done on these!
	
	/**  
		Will execute a function (e.g. assigning a bitmap to an imgTag) in a gamma-neutral context
	**/
	fn fileinGammaDecorator func =
	(
		oldGamma = fileinGamma
		fileinGamma = 1.0
		func()
		fileinGamma = oldGamma
	)--end fn	
	,
	fn setHeaderImage ckb =
	(
		token = (filterString ckb.name "_")[2]
		self.ro.headerImgPth = (getDir #userScripts) + "\\interactiveRenamer\\interactiveRenamer_header_"+token+".png"
		fileinGammaDecorator (fn setHeaderImg=(self.ro.imgTag_header.bitmap = openBitmap self.ro.headerImgPth))
	)--end fn
	,
-- 	fn colorizeHeaderImage clr mult:1.33 =
-- 	(
-- 		-- first reset by getting img from file
-- 		fileinGammaDecorator (fn setHeaderImg=(self.ro.imgTag_header.bitmap = openBitmap self.ro.headerImgPth))
-- 				
-- 		-- then colorize
-- 		oldBitmap = self.ro.imgTag_header.bitmap
-- 		newBitmap = BitMap oldBitmap.width oldBitmap.height
-- 		for row=1 to oldBitmap.height do
-- 		(
-- 			pixels = getPixels oldBitmap [0, row] oldBitmap.width
-- 			newPixels = for p in pixels collect (p*clr*mult)
-- 			setPixels newBitmap [0, row] newPixels
-- 		)--end for
-- 		self.ro.imgTag_header.bitmap = newBitmap
-- 	)--end fn
-- 	,
	fn goToWebsite url =
	(
		weHaveInet = internet.CheckConnection url:url force:true
		if weHaveInet then
			ShellLaunch url ""
		else
			print ("Could not open " + url +". Check your internet connection.")
	)--end fn
	,
	/**
		Function originally by Pete Addington aka LoneRobot
	**/	
	fn convertBase64StringToImage str =
	(
		local ConvertClass = dotNetClass "System.Convert"
		local ImageClass = dotNetClass "System.Drawing.Image"
		
		local byteArr = ConvertClass.FromBase64String str
		local memstream = dotnetobject "System.IO.MemoryStream" byteArr
		local DecodedImg = ImageClass.fromstream memstream
		memstream.close()  
		
		DecodedImg --return
	)--end fn
	,
	/**
		Used to rearrange references array 
		works for things that have a ".name" property
		like objects, materials and layers
	**/
	fn sortByName o1 o2 = 
	(
		-- MAXScript can compare strings directly
		case of
		(
			(o2.name > o1.name): -1
			(o2.name < o1.name): 1
			default: 0
		)--end case
	)--end fn
	,
	/**
		Tries to collect all materials that are nested inside a base material recursively.
		Supports an arbitrary number of materials that can have nested materials inside them
		/param theMat : the base material
		/param arr : the array that all found materials are appended to
	**/
	fn getNestedMaterialsRecursive theMat arr=
	(		
		if theMat != undefined do -- may be undefined e.g. when back material slot of VRay2SidedMtl is empty 
		(
			appendIfUnique arr theMat -- collect this one
		
			case (classof theMat) of -- dig further if there is more to get
			(		
				-- Standard nested materials:
				Multimaterial :
				(
					for m in theMat do
						getNestedMaterialsRecursive m arr
				)
				Blend :
				(
					getNestedMaterialsRecursive theMat.map1 arr
					getNestedMaterialsRecursive theMat.map2 arr
				)
				Shell_Material :
				(
					getNestedMaterialsRecursive theMat.originalMaterial arr
					getNestedMaterialsRecursive theMat.bakedMaterial arr
				)	
				compositematerial :
				(
					getNestedMaterialsRecursive theMat.baseMaterial arr
					for m in theMat.materiallist where m != undefined do 
						getNestedMaterialsRecursive m arr
				)	
				Shellac :
				(
					getNestedMaterialsRecursive theMat.shellacMtl1 arr
					getNestedMaterialsRecursive theMat.shellacMtl2 arr
				)
				TopBottom :
				(
					getNestedMaterialsRecursive theMat.topMaterial arr
					getNestedMaterialsRecursive theMat.bottomMaterial arr
				)			
				DoubleSided :
				(
					getNestedMaterialsRecursive theMat.material1 arr
					getNestedMaterialsRecursive theMat.material2 arr
				)
				-- VRay nested materials:
				VRay2SidedMtl :
				(
					getNestedMaterialsRecursive theMat.frontMtl arr
					getNestedMaterialsRecursive theMat.backMtl arr
				)
				VRayBlendMtl :
				(
					getNestedMaterialsRecursive theMat.baseMtl arr
					for m in a.coatMtl do 
						getNestedMaterialsRecursive m arr
				)
				VRayMtlWrapper :
				(
					getNestedMaterialsRecursive theMat.baseMtl arr
				)
				VRayOverrideMtl :
				(
					getNestedMaterialsRecursive theMat.baseMtl arr
					getNestedMaterialsRecursive theMat.giMtl arr
					getNestedMaterialsRecursive theMat.reflectMtl arr
					getNestedMaterialsRecursive theMat.refractMtl arr
					getNestedMaterialsRecursive theMat.shadowMtl arr
				)
			)--end case	
		)--end if
	)--end fn
	,
	/**************************************************
		RENAMING FUNCTIONS:
	
		Most work on single nameplate-objects and use the struct rollout controls.
		Others (like numbering) take an array of nameplate objects instead of a single one as input.
		The order in which they are applied is important to get a correct final new name.
	**************************************************/
	
	/**
		Sets a base name
	**/
	fn base np =
	(
		np.newName = self.ro.edt_base.text
	)--end fn
	,
	/**
		Adds a prefix to a name
	**/
	fn prefix np =
	(
		np.newName = self.ro.edt_prefix.text + np.newName
	)--end fn
	,
	/**
		Appends a suffix to a name
	**/
	fn suffix np =
	(
		np.newName = np.newName + self.ro.edt_suffix.text
	)--end fn	
	,
	/**
		Removes a given number of characters from a name, starting at the beginning
	**/
	fn remove_first np =
	(
		np.newName = substring np.newName (self.ro.spn_first.value+1) np.newName.count
	)--end fn
	,
	/**
		Removes a given number of characters from a name, starting at the end
	**/
	fn remove_last np =
	(

		if self.ro.spn_last.value >= np.newName.count then -- fix for reappearing of names when deleting more chars than they have
			np.newName = ""
		else
			np.newName = substring np.newName 1 (np.newName.count - self.ro.spn_last.value)
	)--end fn
	,
	/**
		Prepends / appends a numbering to a nameplate based on the supplied index..
	**/
	fn numbered np idx =
	(
		local step = self.ro.spn_numStep.value
		local nr = self.ro.spn_numBase.value - step
		nr = nr + step * idx
		nrStr = ""
		-- Add padding:
		for j = ((nr as String).count + 1) to self.ro.spn_digits.value do
			nrStr += "0"
		nrStr += nr as String
		
		if self.ro.rdo_num.state == 2 then --trailing number
			np.newName = np.newName + nrStr
		else --leading number
			np.newName = nrStr + np.newName
	)--end fn
	,
	/**
		A function to search and replace string parts, with the option to check case and 
		replace first only or all occurences of the search term. It is separated from the initializing
		function so it can be reused elsewhere.
	
		This is quite an abomination as it supports replacing all occurences of a string,
		which is not possible to do with matchPattern or findString alone, but instead a mixture of both.
		Also has some code duplication which could probably be refined a lot.
	
		/param txt: String
		/param searchFor: String
		/param replaceWith: String
		/optParam all: Boolean
		/optParam ignoreCase: Boolean
		/returns: String 
	**/		
	fn search_replace_all txt searchFor replaceWith all:true ignoreCase:false=
	(
		if searchFor != replaceWith then
		(
			local sIdx = findString txt searchFor -- check if there is anything to work with
			
			/** 
				ALL occurences being replaced 
			**/
			if all then
			(
				caseCheckFailedOccurences = #() -- to be used for string reconstruction later
				-- check string for search term
				while sIdx != undefined do
				(
					if not ignoreCase then -- if case check is wanted
					(	
						-- isolate the found occurence
						local temp = substring txt sIdx searchFor.count
						--if case fits for occ, replace that part of the original string
						if (matchPattern temp pattern:("*" + searchFor + "*") ignoreCase:false) then 
						(
							txt = replace txt sIdx searchFor.count replaceWith
						)--end if
						else -- cut string and replace txt with right part
						(
							-- store left part including temp in array
							left = ""
							for i = 1 to (sIdx + searchFor.count - 1) do
								left += txt[i]
							append caseCheckFailedOccurences left
							-- replace txt with part right of temp
							right = ""
							for i = (sIdx + searchFor.count) to txt.count do
							right += txt[i]							
							txt = right
						)--end else
					)--end if
					else -- no case check
					(
						txt = replace txt sIdx searchFor.count replaceWith
					)--end else
					
					sIdx = findString txt searchFor -- update index
-- 					print ("sIdx = " + sIdx as String + ", temp = " + temp as String + ", txt = " + txt as String + ", ........... " + caseCheckFailedOccurences as String)
				)--end while
				
				-- construct resulting string
				result = ""
				for s in caseCheckFailedOccurences do
					result += s
				result += txt
-- 				print ("RESULT = " + result as String)
			)--end if all
			
			/** 
				Only FIRST occurence MOST CODE JUST COPIED FROM ABOVE
			**/
			else  
			(
				if sIdx != undefined do
				(
					if not ignoreCase then -- if case check is wanted
					(						
						-- isolate the found occurence
						temp = substring txt sIdx searchFor.count
						--if case fits for occ, replace that part of the original string
						if (matchPattern temp pattern:("*" + searchFor + "*") ignoreCase:false) then 
						(
							txt = replace txt sIdx searchFor.count replaceWith
						)--end if
						else () -- do nothing)
					)--end if
					else -- no case check
					(
						txt = replace txt sIdx searchFor.count replaceWith
					)--end else
					result = txt
				)--end if
			)--end else
			result -- return new name
		)
		else
			txt -- return unchanged
	)--end fn	
	,
	/**
		This function does NOT do the actual search & replace, 
		but it uses another function to do the renaming
	**/
	fn initialize_search_replace np = 
	(
		if self.ro.edt_search != "" do --at least give sth to search for, but allow to replace with nothing
		(
			-- replace old name with function result
			if not self.ro.edt_search.text == self.ro.edt_replace.text and (findString np.newName self.ro.edt_search.text) != undefined and self.ro.edt_search.text != "" do -- some initial checks, need to check for empty string here again if search field is emptied 
			(
				np.newName = search_replace_all np.newName self.ro.edt_search.text self.ro.edt_replace.text all:self.ro.chk_allOcc.checked ignoreCase:(not self.ro.chk_case.checked)
			)--end if		
		)--end if
	)--end fn
	,
	fn getSelectedNameplates nameplates selectionIndices =
	(
		selectedNameplates = for i=1 to nameplates.count where findItem selectionIndices i != 0 collect nameplates[i]
		selectedNameplates -- return
	)--end fn
	,
	/**
		Creates the new names and stores them in the nameplates, but does not assign it to the references.
		Works only on names that are selected in the listbox, so we can do a selective renaming.
	**/
	fn constructNewNames nameplates =
	(
		for i=1 to nameplates.count do
		(
			np = nameplates[i]
			if self.ro.chk_base.checked do base np
			if self.ro.chk_first.checked do remove_first np
			if self.ro.chk_last.checked do remove_last np
			if self.ro.chk_prefix.checked do prefix np
			if self.ro.chk_suffix.checked do suffix np
			if self.ro.chk_num.checked do numbered np i
			if self.ro.chk_snr.checked do initialize_search_replace np -- this fn does not do the SnR it self, but triggers it
		)--end for
	)--end fn	
	,
	/**
		Assigns the newName of the nameplates to its references.
	**/
	fn assignNewNames nameplates =
	(
		self.ro.pb.value = 0
		for i=1 to nameplates.count do
		(
			np = nameplates[i]
			np.assignNameToRef()
			
			-- Update nameplate afterwards to make sure
			np.name = np.getNameFromRef()
			np.newName = np.name
			
			self.ro.pb.value = 100.0 / nameplates.count * i
		)--end for
	)--end fn
	,
	/**
		Meant for quick changes on single names that dont fit a certain pattern for mass renaming.
		Triggered by doubleclicking an item in list.
	**/
	fn quickSingleRename np =
	(
		try(destroyDialog ro_quickSingleRename)catch()
		rollout ro_quickSingleRename ("Manual rename:") width:484 height:53
		(				
			local self = undefined
			local np = undefined
			
			edittext edt_name "" pos:[0,4] width:479 height:16
			button btn_ok "OK" pos:[343,26] width:66 height:22
			button btn_cancel "Cancel" pos:[414,26] width:66 height:22
			
			on btn_ok pressed do
			(
				if edt_name.text != np.name do
				(
					if self.ro.doublecheckFileRenaming() do
					(
						np.newName = edt_name.text
						self.assignNewNames #(np)
						
						-- Manual update needed here for assets and files
						if self.ro.ckb_assets.checked or self.ro.ckb_files.checked do
						(
							self.ro.updateNameplates()
						)--end if
						
						self.ro.updateList()
					)--end if
				)--end if
				destroyDialog ro_quickSingleRename
			)--end on
			on btn_cancel pressed do
			(
				destroyDialog ro_quickSingleRename
			)--end on
		)
		createDialog ro_quickSingleRename 484 53 (mouse.screenpos.x - 42) (mouse.screenpos.y - 30) \
			style:#(#style_titlebar, #style_border, #style_sysmenu, #style_toolwindow)

		-- Hacky way to set focus when the dialog opens up
		setFocus ro_quickSingleRename.edt_name
		ro_quickSingleRename.edt_name.text = " " -- pass nonsense so the next pass is a change, which enables the "entered" event
		ro_quickSingleRename.edt_name.text = np.name -- pass old name for editing
		-- Pass references to rollout
		ro_quickSingleRename.self = self
		ro_quickSingleRename.np = np
	)--end fn
	,
-- 	-- WIP
-- 	/**
-- 		This is basically a small specialized tool on its own:
-- 	
-- 		If some assets or files are renamed and given to this function,
-- 		it can apply the same renaming to the asset's file or the file's assets
-- 		so they match again in the asset tracker.
-- 		This of course only works if the files are found. 
-- 		Nameplates must be given to this function 
-- 		
-- 		Be aware that the asset tracker creates its paths based on the current project directory,
-- 		so it may e.g. contain "\..\..\foo.jpg" which would have to be converted into an absolute path first.
-- 	**/
-- 	fn syncAssetsAndFiles nameplates =
-- 	(
-- 		-- To analyze assets and files we create another tool and factory instance
-- 		local _self = InteractiveRenamer()
-- 		if gInteractiveRenamer.ro.rdo_source.state == 2 then mode = "selection" else mode = "scene"
-- 		case of
-- 		(
-- 			(classof nameplates[1] == AssetNameplate): _self.factory = NameplateFactory type:"assets"
-- 			(classof nameplates[1] == FileNameplate): _self.factory = NameplateFactory type:"files"
-- 		)--end case
-- 		
-- 	)--end fn
-- 	,
	ro = rollout ro "There should be a mode header in here, not this text" width:896 height:398
	(
		
		/**
			Reference to parent struct.
			Assign after rollout creation (init) to use parent methods in UI events!
			See: http://www.losart3d.com/?p=475
		**/
		local self = undefined
		local recentDir = "" -- Last path of file mode
		
		local recentDir = "" -- from/to INI to remember last path for file mode
		local headerImgPth = (getDir #userScripts) + "\\interactiveRenamer\\interactiveRenamer_header.png"

		local clr_objects = color 50 105 215
		local clr_materials = color 160 60 40
		local clr_layers = color 60 40 160
		local clr_files = color 10 150 50
		local clr_assets = color 150 160 60
		
		ImgTag imgTag_header "Label" pos:[0,0] width:896 height:18
		HyperLink hyp_website "www.cbuelter.de" pos:[795,3] width:85 height:16 color:(color 255 255 255) address:"http://www.cbuelter.de"
		
		checkbox chk_prefix "Prefix: " pos:[11,127] width:56 height:16
		edittext edt_prefix "" pos:[66,127] width:135 height:16
		checkbox chk_first "Remove first: " pos:[11,106] width:87 height:16
		label lbl2 "Digits" pos:[153,107] width:31 height:16
		checkbox chk_suffix "Suffix: " pos:[11,185] width:54 height:16
		edittext edt_suffix "" pos:[66,185] width:135 height:16
		checkbox chk_last "Remove last: " pos:[11,164] width:87 height:16
		spinner spn_first "" pos:[99,106] width:49 height:16 range:[0,100,0] type:#integer scale:1
		spinner spn_last "" pos:[99,164] width:49 height:16 range:[0,100,0] type:#integer scale:1
		label lbl4 "Digits" pos:[153,165] width:31 height:16
		checkbox chk_num "Numbered: " pos:[11,217] width:73 height:16
		spinner spn_NumBase "Base: " pos:[120,240] width:73 height:16 range:[0,99999,0] type:#integer scale:1
		spinner spn_NumStep "Step: " pos:[126,261] width:67 height:16 range:[1,999,1] type:#integer scale:1
		radiobuttons rdo_num "" pos:[93,218] width:99 height:16 labels:#("lead", "trail") default:2 columns:2
		checkbox chk_base "Base name: " pos:[11,72] width:79 height:16
		edittext edt_base "" pos:[89,72] width:112 height:16
		checkbox chk_snr "Search for: " pos:[11,295] width:77 height:16
		edittext edt_search "" pos:[89,295] width:112 height:16
		edittext edt_replace "" pos:[95,317] width:106 height:16
		label lbl6 "Replace with: " pos:[29,317] width:66 height:16
		checkbox chk_case "Case sensitive" pos:[27,339] width:90 height:16  
		checkbox chk_allOcc "All" pos:[121,339] width:40 height:16 
		button btn_swap " Swap" pos:[161,339] width:40 height:18 
		spinner spn_digits "Digits: " pos:[44,240] width:40 height:16 range:[0,20,3] type:#integer scale:1
		
		checkbutton ckb_objects "Objects" pos:[9,25] width:60 height:38 highlightColor:clr_objects checked:true 
		checkbutton ckb_materials "Materials" pos:[73,25] width:60 height:38 highlightColor:clr_materials
		checkbutton ckb_layers "Layers" pos:[137,25] width:60 height:38 highlightColor:clr_layers
		checkbutton ckb_files "Files" pos:[265,25] width:60 height:38 highlightColor:clr_files
		checkbutton ckb_assets "Assets" pos:[201,25] width:60 height:38 highlightColor:clr_assets
		
-- 		edittext dn_textbox_folder "" pos:[333,41] width:454 height:16 
		dotNetControl dn_textbox_folder "TextBox" pos:[333,41] width:454 height:16 
		label lbl_getNames "Get names from: " pos:[334,24] width:82 height:16
		checkbox chk_nestedMats "Get nested materials" pos:[600,24] width:250 height:16 checked:true
		radiobuttons rdo_source "" pos:[426,24] width:195 height:16 labels:#("Scene", "Selected Objects") default:2
		button btn_getFiles " ..." pos:[792,40] width:71 height:22 toolTip:"LMB: Browse folder, RMB: Open path in windows explorer"
		button btn_refresh "R" pos:[867,40] width:22 height:22 toolTip:"Refresh list" 
		
		multiListBox lbx_names "" pos:[210,72] width:674 height:22 readOnly:false 
		progressBar pb "ProgressBar" pos:[886,71] width:8 height:294 color:(color 255 255 0) orient:#vertical
		
		checkbutton ckb_sort "Sort" pos:[209,370] width:45 height:24 checked:false visible:true
		button btn_selAll "All" pos:[258,370] width:45 height:24 visible:true
		button btn_selNone "None" pos:[307,370] width:45 height:24 visible:true
		edittext edt_filter "Filter:" pos:[359,374] width:100 height:18
		label lbl_count "" pos:[465,376] width:80 height:18 
		
		button btn_rename "Rename" pos:[695,370] width:190 height:24 enabled:true toolTip:"Rename (make sure to select names in the list first)" 
		checkbutton ckb_preview "Preview" pos:[11,370] width:190 height:24 highlightColor:clr_objects checked:true
		
		/**
			Methods here should only deal with UI events and stuff like that.
			Renaming functionality resides in the parent struct (self).
		**/
		
		/**
			Here: needs directory "interactiveRenamer" to already be created! the MZP should do that
		**/
		fn save_to_INI =
		(
			local pth = (getDir #userscripts) + "\\interactiveRenamer\\\interactiveRenamer.ini"
			setINISetting pth "Recent Paths" "fileModeDir" recentDir
		)--end fn
		
		fn load_from_INI =
		(
			local pth = (getDir #userscripts) + "\\interactiveRenamer\\\interactiveRenamer.ini"
			print pth
			if doesFileExist pth do
			(
				recentDir = getINISetting pth "Recent Paths" "fileModeDir" 
			)--end if
		)--end fn
		
		fn registerCallbacks =
		(
			callbacks.removeScripts id:#interactiveRenamer
			callbacks.addscript #selectionSetChanged "gInteractiveRenamer.ro.updateOnSelectionChange()" id:#interactiveRenamer
		)--end fn
		
		fn unregisterCallbacks =
		(
			callbacks.removeScripts id:#interactiveRenamer
		)--end fn
		
		/**
			This makes sure the selectionSetChanged callback only takes action in a mode that supports selections.
			Used by callback so use a global reference!
		**/
		fn updateOnSelectionChange = 
		(		
			if gInteractiveRenamer.ro.ckb_objects.checked or \
				gInteractiveRenamer.ro.ckb_materials.checked or \
				gInteractiveRenamer.ro.ckb_layers.checked do 
					gInteractiveRenamer.ro.updateAll()		
		)--end fn
		
		fn ckbForceColorUpdate ckb clr =
		(
			ckb.highlightColor = clr
			temp = ckb.caption
			ckb.caption = ""
			ckb.caption = temp
		)--end fn
		
		fn passesFilter nameplate filtertxt =
		(
			if findString nameplate.name filtertxt != undefined or filtertxt == "" then True	
			else False
		)--end fn
		
		fn updateNestedMatsCheckbox =
		(
			if ckb_materials.checked do
			(
				if rdo_source.state == 2 then
					chk_nestedMats.enabled = True
				else
					chk_nestedMats.enabled = False
			)--end if
		)--end fn
		
		fn updateFileModePath = 
		(
			dn_textbox_folder.text = recentDir
		)--end fn
		
		/**
			This updates not only the checkbuttons (so they behave like a radiogroup), but also many other things based on the given ckb.
		**/
		fn updateCheckbuttons ckb =
		(
-- 			self.setHeaderImage ckb
			case ckb of
			( 
				(ckb_Objects): 
				(
					ckb_Materials.checked=False; ckb_Layers.checked=False; ckb_Assets.checked=False; ckb_Files.checked=False
					lbl_getNames.enabled=True; rdo_source.enabled=True; chk_nestedMats.enabled=False; dn_textbox_folder.enabled=False; btn_getFiles.enabled=False; btn_refresh.enabled=False
					ckbForceColorUpdate ckb_preview clr_objects; ckbForceColorUpdate ckb_sort clr_objects; pb.color=clr_objects; pb.value=0
					self.ro.title = "Object Mode"
				)
				(ckb_Materials): 
				(
					ckb_Objects.checked=False; ckb_Layers.checked=False; ckb_Assets.checked=False; ckb_Files.checked=False
					lbl_getNames.enabled=True; rdo_source.enabled=True; chk_nestedMats.enabled=True; dn_textbox_folder.enabled=False; btn_getFiles.enabled=False; btn_refresh.enabled=False
					ckbForceColorUpdate ckb_preview clr_materials; ckbForceColorUpdate ckb_sort clr_materials; pb.color=clr_materials; pb.value=0
					self.ro.title = "Material Mode"
					
					updateNestedMatsCheckbox()
				)
				(ckb_Layers): 
				(
					ckb_Materials.checked=False; ckb_Objects.checked=False; ckb_Assets.checked=False; ckb_Files.checked=False
					lbl_getNames.enabled=True; rdo_source.enabled=True; chk_nestedMats.enabled=False; dn_textbox_folder.enabled=False; btn_getFiles.enabled=False; btn_refresh.enabled=False
					ckbForceColorUpdate ckb_preview clr_layers; ckbForceColorUpdate ckb_sort clr_layers; pb.color=clr_layers; pb.value=0
					self.ro.title = "Layer Mode"
				)
				(ckb_Assets): 
				(
					ckb_Materials.checked=False; ckb_Objects.checked=False; ckb_Layers.checked=False; ckb_Files.checked=False
					lbl_getNames.enabled=False; rdo_source.enabled=False; chk_nestedMats.enabled=False; dn_textbox_folder.enabled=False; btn_getFiles.enabled=False; btn_refresh.enabled=False
					ckbForceColorUpdate ckb_preview clr_assets; ckbForceColorUpdate ckb_sort clr_assets; pb.color=clr_assets; pb.value=0
					self.ro.title = "Asset Mode"
				)
				(ckb_Files): 
				(
					ckb_Materials.checked=False; ckb_Layers.checked=False; ckb_Assets.checked=False; ckb_Objects.checked=False
					lbl_getNames.enabled=False; rdo_source.enabled=False; chk_nestedMats.enabled=False; dn_textbox_folder.enabled=True; btn_getFiles.enabled=True; btn_refresh.enabled=True
					ckbForceColorUpdate ckb_preview clr_files; ckbForceColorUpdate ckb_sort clr_files; pb.color=clr_files; pb.value=0
					self.ro.title = "File Mode"
				)
			)--end case
		)--end fn
		
		fn updateRenameButton =
		(
			if self.nameplates.count != 0 and self.nameplatesInList != 0 and not lbx_names.selection.isEmpty then
			(
				btn_rename.enabled = True
				btn_rename.caption = "Rename"
			)
			else
			(
				btn_rename.enabled = False
				btn_rename.caption = "Select something in the list!"
			)--end else
		)--end fn
		
		fn updateFactory =
		(
			if rdo_source.state == 2 then mode = "selection" else mode = "scene"
			case of
			(
				(ckb_Objects.checked): self.factory = NameplateFactory type:"objects" mode:mode
				(ckb_Materials.checked): self.factory = NameplateFactory type:"materials" mode:mode nested:chk_nestedMats.checked
				(ckb_Layers.checked): self.factory = NameplateFactory type:"layers" mode:mode
				(ckb_Assets.checked): self.factory = NameplateFactory type:"assets" mode:mode
				(ckb_Files.checked): self.factory = NameplateFactory type:"files" mode:mode dir:recentDir
			)--end case
		)--end fn
		
		fn updateNameplates =
		(
			self.factory.collectRefs()
			self.nameplates = self.factory.buildNameplates()
		)--end fn
				
		/**
			Manages the filtering and sorting of the nameplates, so we can only work on and display those in the list.
		**/
		fn updateNameplatesInList = 
		(
			self.nameplatesInList = for np in self.nameplates where passesFilter np edt_filter.text collect np
			if ckb_sort.checked do	
				qsort self.nameplatesInList self.sortByName
		)--end fn
		
		/**
			E.g. to discard the preview name before doing the actual renaming.
		**/
		fn resetNameplatesNewNames nameplates =
		(
			for np in nameplates do 
				np.newName = np.name
		)--end fn
		
		/**
			Main function to display names in the list.
			Does all the sorting, filtering and previewing to display nameplates in the listbox.
		**/
		fn updateList =
		(
			resetNameplatesNewNames self.nameplates
			updateNameplatesInList()
		
			if ckb_preview.checked then
			(
				selectedNameplates = self.getSelectedNameplates self.nameplatesInList lbx_names.selection
				self.constructNewNames selectedNameplates
				namelist = for np in self.nameplatesInList collect np.newName
			)
			else
				namelist = for np in self.nameplatesInList collect np.name
			
			lbx_names.items = namelist
			lbl_count.text = namelist.count as String + " found"
				
			updateRenameButton()
		)--end fn
		
		fn updateAll =
		(
			updateFactory()
			updateNameplates()
			updateList()
			updateNestedMatsCheckbox()
			updateFileModePath()
		)--end fn
		
		fn getFilesFromFolder =
		(
			if dn_textbox_folder.text != "" and (doesFileExist dn_textbox_folder.text) then 
				iniDir = dn_textbox_folder.text
			else 
				iniDir = "C:\\"
			local pth = getSavePath caption:"Scan folder for files:" initialDir:iniDir
			if pth != undefined do
			(
				self.factory.dir = pth -- the getReferencesAndNames fn uses this to get the files, so i dont have to pass it to the fn
				updateNameplates()
				updateList()
				
				dn_textbox_folder.text = pth
				
				-- TODO remember this
-- 				recentDir = pth
-- 				save_to_INI()
			)--end if
		)--end fn
		
		fn doublecheckFileRenaming =
		(
			allowed = True
			if ckb_files.checked do
				allowed = querybox "Are you sure you want to permanently rename these files?" title:"WARNING" 
			allowed --return
		)--end fn

		-- This fn replaces the "on open do" handler and is responsible to make the rollout aware of the struct instance.
		fn init pself = 
		(
			self = pself
			-- When assigning the header image, make sure to set gamma to 1.0 first and reset afterwards
			self.fileinGammaDecorator (fn setHeaderImg=(imgTag_header.bitmap = openBitmap headerImgPth))
			-- Enable initial callbacks
			if rdo_source.state == 2 do registerCallbacks()
				
			-- Get INI settings
			load_from_INI()
				
			updateCheckbuttons ckb_objects -- hides/enables other gui stuff
			updateAll()
		)--end fn
		
		/**
			Event handlers
		**/
		on ro close do self.close()
		
		on ckb_objects changed state do
		(
			if state then
			(
				updateCheckbuttons ckb_objects
				updateAll()
			)
			else ckb_objects.checked=True
		)--end on
		
		on ckb_materials changed state do
		(
			if state then
			(
				updateCheckbuttons ckb_materials
				updateAll()
			)
			else ckb_materials.checked=True
		)--end on
		
		on ckb_layers changed state do
		(
			if state then
			(
				updateCheckbuttons ckb_layers
				updateAll()
			)
			else ckb_layers.checked=True
		)--end on
		
		on ckb_assets changed state do
		(
			if state then
			(
				updateCheckbuttons ckb_assets
				updateAll()
			)
			else ckb_assets.checked=True
		)--end on
		
		on ckb_files changed state do
		(
			if state then
			(
				updateCheckbuttons ckb_files
				updateAll()
			)
			else ckb_files.checked=True
		)--end on
		
		on btn_getFiles pressed do
		(
			getFilesFromFolder()
		)--end fn
		
		on btn_refresh pressed do
		(
			if	dn_textbox_folder.text != "" and
				doesFileExist dn_textbox_folder.text and
				getFileAttribute dn_textbox_folder.text #directory do
				(
					updateNameplates()
					updateList()
				)--end if
		)--end on
		
		on btn_getFiles rightClick do
		(
			if	dn_textbox_folder.text != "" and
				doesFileExist dn_textbox_folder.text and
				getFileAttribute dn_textbox_folder.text #directory do
					ShellLaunch dn_textbox_folder.text ""
		)--end on
				
		on btn_rename pressed do 
		(			
			resetNameplatesNewNames self.nameplates
			updateNameplatesInList()
			
			selectedNameplates = self.getSelectedNameplates self.nameplatesInList lbx_names.selection
			
			if doublecheckFileRenaming() do
			(
				self.constructNewNames selectedNameplates
				self.assignNewNames selectedNameplates
				
				-- Assets and files need to be updated manually to show correctly in the list
				if ckb_assets.checked or ckb_files.checked do
					updateNameplates()
				
				updateList()
			)--end if
		)--end on
		
		on btn_selAll pressed do 
		(
			lbx_names.selection = #all
			updateList()
		)--end on
		
		on btn_selNone pressed do 
		(
			lbx_names.selection = #none			
			updateList()
		)--end on
		
		on btn_swap pressed do
		(
			temp = edt_search.text
			edt_search.text = edt_replace.text
			edt_replace.text = temp
			updateList()
		)--end on
				
		on lbx_names doubleclicked idx do 
		(
			self.quickSingleRename self.nameplatesInList[idx]
		)--end on
		
		on lbx_names selectionEnd do 
		(
			if ckb_preview.checked do
				updateList()
		)--end on
		
		on rdo_source changed state do 
		(
			if state == 2 then
				registerCallbacks()
			else
				unregisterCallbacks()
			updateAll()
		)--end on
		
		on edt_filter changed txt do 
		(
-- 			lbx_names.selection = #none
			updateList()
		)--end on
		
		on dn_textbox_folder TextChanged evn do
		(
			if dn_textbox_folder.text != "" and
				doesFileExist dn_textbox_folder.text and
				getFileAttribute dn_textbox_folder.text #directory then
				(
					self.factory.dir = dn_textbox_folder.text					
					-- Remember path for next session
					recentDir = dn_textbox_folder.text
					save_to_INI()
				)
				else
				(
					self.factory.dir = ""	
				)--end else
				
				updateNameplates()
				updateList()
		)--end on
		
		on dn_textbox_folder KeyUp keyArg do
		(
			if keyArg.KeyValue == 13 do -- if ENTER pressed
				setFocus ro -- Leave textbox, so that autocomplete suggestion list is closed
		)--end on
		
		on chk_nestedMats changed state do updateAll()
		
		on ckb_preview changed state do updateList()
		on ckb_sort changed state do updateList()
		on edt_prefix changed txt do updateList()
		on edt_suffix changed txt do updateList()
		on edt_search changed txt do updateList()
		on edt_replace changed txt do updateList()
		on edt_base changed txt do updateList()
		on spn_first changed val do updateList()
		on spn_last changed val do updateList()
		on spn_NumBase changed val do updateList()
		on spn_NumStep changed val do updateList()
		on spn_digits changed val do updateList()
		on chk_base changed state do updateList()
		on chk_case changed state do updateList()
		on chk_allOcc changed state do updateList()
		on chk_snr changed state do updateList()
		on chk_num changed state do updateList()
		on chk_last changed state do updateList()
		on chk_suffix changed state do updateList()
		on chk_prefix changed state do updateList()
		on chk_first changed state do updateList()
		on rdo_num changed state do	updateList()
		
	)--end rollout
	,
	fn show = 
	(	
		createDialog ro style:#(#style_titlebar, #style_border, #style_sysmenu, #style_toolwindow)
		ro.init self
		
		-- For some reason we must set it here, setting it as default in the rollout would disable it forever
		ro.dn_textbox_folder.enabled = False
		-- Enable autocompletion
		ro.dn_textbox_folder.AutoCompleteMode = (dotnetClass "System.Windows.Forms.AutoCompleteMode").Suggest 
		ro.dn_textbox_folder.AutoCompleteSource  = (dotnetClass "System.Windows.Forms.AutoCompleteSource").FileSystemDirectories 
	)--end fn
	,
	fn close = 
	(
		ro.unregisterCallbacks()
		try
		(
			destroyDialog ro
			gInteractiveRenamer = undefined
		) catch()
	)--end fn
)--end struct

-- Execute script -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
try(gInteractiveRenamer.close())catch()
gInteractiveRenamer = InteractiveRenamer()
gInteractiveRenamer.self = gInteractiveRenamer
gInteractiveRenamer.show()