fileIn "nameplates.ms"

struct InteractiveRenamer
(
	version = 2.0,
	self,
	factory,
	nameplates,
	
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
		Here: needs directory "interactiveRenamer" to already be created! the MZP should do that
	**/
	fn save_to_INI=
	(
		local pth = (getDir #userscripts) + "\\interactiveRenamer\\\interactiveRenamer.ini"
		setINISetting pth "Recent Paths" "presets" recentDir
	)--end fn
	,
	fn load_from_INI=
	(
		local pth = (getDir #userscripts) + "\\interactiveRenamer\\\interactiveRenamer.ini"
		if doesFileExist pth do
		(
			recentDir = getINISetting pth "Recent Paths" "presets" 
		)--end if
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
	FIXME: MAKE IT WORK ON SELECTED ONLY -- hand another array to the fn!
		Adds / appends a numbering to a list of names, with the option to change the base and step values
		CURRENTLY WORKS DIRECTLY ON THE nameplates ARRAY OF THE STRUCT
	**/
	fn numbered npArray =
	(
		local step = self.ro.spn_numStep.value
		local nr = self.ro.spn_numBase.value - step
		for i=1 to npArray.count do
		(
			--iterate nr
			nr = (nr as Integer) + step
			--prefix zeros
			nrStr = ""
			for j = ((nr as String).count + 1) to self.ro.spn_digits.value do
				nrStr += "0"
			nrStr += nr as String
			
			if self.ro.rdo_num.state == 2 then --trailing number
				npArray[i].newName = npArray[i].newName + nrStr
			else --leading number
				npArray[i].newName = nrStr + npArray[i].newName
		)--end for
	)--end fn
	,
	/**
		A function to search and replace string parts, with the option to check case and 
		replace first only or all occurences of the search term. It is separated from the initializing
		function so it can be reused elsewhere.
	
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
	fn constructNewNames nameplates =
	(
		for np in nameplates do
		(
			-- reset newName
			np.newName = np.name
			-- create new newName:
			if self.ro.chk_base.checked do base np
			if self.ro.chk_first.checked do remove_first np
			if self.ro.chk_last.checked do remove_last np
			if self.ro.chk_prefix.checked do prefix np
			if self.ro.chk_suffix.checked do suffix np
			if self.ro.chk_num.checked do numbered nameplates
			if self.ro.chk_snr.checked do initialize_search_replace np -- this fn does not do the SNR it self, but triggers it
			
			print (np.name + "  -->  " + np.newName)
		)--end for
	)--end fn	
	,
	ro = rollout ro "Object Mode" width:896 height:382
	(
		/**
			Reference to parent struct.
			Assign after rollout creation (init) to use parent methods in UI events!
			See: http://www.losart3d.com/?p=475
		**/
		local self = undefined
		
		local recentDir = "" -- from/to INI to remember last path for file mode
		local headerImgPth = (getDir #userScripts) + "\\interactiveRenamer\\interactiveRenamer_header03.jpg"

		local clr_objects = (color 50 105 215)
		local clr_materials = (color 160 60 40)
		local clr_layers = (color 60 40 160)
		local clr_files = (color 10 150 50)
		
		checkbox chk_prefix "Prefix: " pos:[11,132] width:56 height:16
		edittext edt_prefix "" pos:[66,132] width:135 height:16
		checkbox chk_first "Remove first: " pos:[11,111] width:87 height:16
		label lbl2 "Digits" pos:[153,112] width:31 height:16
		checkbox chk_suffix "Suffix: " pos:[11,190] width:54 height:16
		edittext edt_suffix "" pos:[66,190] width:135 height:16
		checkbox chk_last "Remove last: " pos:[11,169] width:87 height:16
		spinner spn_first "" pos:[99,111] width:49 height:16 range:[0,100,0] type:#integer scale:1
		spinner spn_last "" pos:[99,169] width:49 height:16 range:[0,100,0] type:#integer scale:1
		label lbl4 "Digits" pos:[153,170] width:31 height:16
		checkbox chk_num "Numbered: " pos:[11,222] width:73 height:16
		spinner spn_NumBase "Base: " pos:[117,245] width:73 height:16 range:[0,99999,0] type:#integer scale:1
		spinner spn_NumStep "Step: " pos:[123,266] width:67 height:16 range:[1,999,1] type:#integer scale:1
		radiobuttons rdo_num "" pos:[93,223] width:99 height:16 labels:#("lead", "trail") default:2 columns:2
		checkbox chk_base "Base name: " pos:[11,77] width:79 height:16
		edittext edt_base "" pos:[89,77] width:112 height:16
		checkbox chk_snr "Search for: " pos:[11,300] width:77 height:16
		edittext edt_search "" pos:[89,300] width:112 height:16
		edittext edt_replace "" pos:[95,322] width:106 height:16
		label lbl6 "Replace with: " pos:[29,322] width:66 height:16
		checkbox chk_case "Case sensitive" pos:[27,344] width:90 height:16  
		checkbox chk_allOcc "All" pos:[121,344] width:40 height:16 
		button btn_swap " Swap" pos:[161,344] width:40 height:18 
		checkbutton ckb_objects "Objects" pos:[9,25] width:60 height:38 highlightColor:(color 50 105 215) checked:true 
		checkbutton ckb_materials "Materials" pos:[73,25] width:60 height:38 highlightColor:(color 160 60 40)
		checkbutton ckb_layers "Layers" pos:[137,25] width:60 height:38 highlightColor:(color 60 40 160)
		checkbutton ckb_files "Files" pos:[201,25] width:60 height:38 highlightColor:(color 10 150 50)
		checkbutton ckb_preview "Preview" pos:[500,358] width:190 height:38 highlightColor:(color 50 105 215) checked:true
		dotNetControl dn_textbox_folder "TextBox" pos:[268,42] width:519 height:16 
		button btn_getFiles " ..." pos:[792,41] width:71 height:22 enabled:false toolTip:"LMB: Browse folder, RMB: Open path in windows explorer"
		button btn_refresh "R" pos:[867,41] width:22 height:22 enabled:false toolTip:"Refresh list" 
		multiListBox lbx_names "" pos:[210,72] width:674 height:22 readOnly:false 
		progressBar pb "ProgressBar" pos:[886,71] width:8 height:309 color:(color 255 255 0) orient:#vertical
		GroupBox grp1 "" pos:[2,66] width:206 height:314
		GroupBox grp4 "" pos:[2,14] width:893 height:56
		spinner spn_digits "Digits: " pos:[41,245] width:40 height:16 range:[0,20,3] type:#integer scale:1
		button btn_rename "Rename" pos:[695,358] width:190 height:22 enabled:true toolTip:"Rename files (old names are lost!)" 
		radiobuttons rdo_source "" pos:[369,25] width:195 height:16 labels:#("Selected Objects", "Scene") columns:2
		label lbl_getNames "Get names from: " pos:[275,25] width:82 height:16
		checkbox chk_nestedMats "Get nested materials" pos:[535,25] width:250 height:16 enabled:false checked:true
		label lbl_count "" pos:[216,358] width:68 height:16
		ImgTag imgTag_header "label" pos:[0,0] width:896 height:18
		checkbutton ckb_sort "Sort" pos:[315,358] width:30 height:16 checked:false visible:true
		button btn_selAll "All" pos:[349,358] width:30 height:16 visible:true
		button btn_selNone "None" pos:[383,358] width:35 height:16 visible:true
		HyperLink hyp_website "www.cbuelter.de" pos:[795,3] width:85 height:16 color:(color 255 255 255) address:"http://www.cbuelter.de"
		
		/**
			Methods here should only deal with UI events and stuff like that.
			Core functionality lies in the parent struct (self).
		**/
		
		fn ckbForceColorUpdate ckb clr =
		(
			ckb.highlightColor = clr
			temp = ckb.caption
			ckb.caption = ""
			ckb.caption = temp
		)--end fn
		
		fn updateCheckbuttons ckb =
		(
			case ckb of
			( 
				(ckb_Objects): 
				(
					ckb_Materials.checked=False; ckb_Layers.checked=False; ckb_Files.checked=False
					rdo_source.enabled=True; chk_nestedMats.enabled=False; dn_textbox_folder.enabled=False; btn_getFiles.enabled=False; btn_refresh.enabled=False
					ckbForceColorUpdate ckb_preview clr_objects; 
				)
				(ckb_Materials): 
				(
					ckb_Objects.checked=False; ckb_Layers.checked=False; ckb_Files.checked=False
					rdo_source.enabled=True; chk_nestedMats.enabled=True; dn_textbox_folder.enabled=False; btn_getFiles.enabled=False; btn_refresh.enabled=False
					ckbForceColorUpdate ckb_preview clr_materials; 
				)
				(ckb_Layers): 
				(
					ckb_Materials.checked=False; ckb_Objects.checked=False; ckb_Files.checked=False
					rdo_source.enabled=False; chk_nestedMats.enabled=False; dn_textbox_folder.enabled=False; btn_getFiles.enabled=False; btn_refresh.enabled=False
					ckbForceColorUpdate ckb_preview clr_layers; 
				)
				(ckb_Files): 
				(
					ckb_Materials.checked=False; ckb_Layers.checked=False; ckb_Objects.checked=False
					rdo_source.enabled=False; chk_nestedMats.enabled=False; dn_textbox_folder.enabled=True; btn_getFiles.enabled=True; btn_refresh.enabled=True
					ckbForceColorUpdate ckb_preview clr_files; 
				)
			)--end case
		)--end fn
		
		fn updateFactory =
		(
			if rdo_source.state == 1 then mode = "selection" else mode = "scene"
			case of
			(
				(ckb_Objects.checked): self.factory = NameplateFactory type:"objects" mode:mode
				(ckb_Materials.checked): self.factory = NameplateFactory type:"materials" mode:mode
				(ckb_Layers.checked): self.factory = NameplateFactory type:"layers" mode:mode
				(ckb_Files.checked): self.factory = NameplateFactory type:"files" mode:mode
			)--end case
			print self.factory
		)--end fn
		
		fn updateNameplates =
		(
			self.factory.collectRefs()
			self.nameplates = self.factory.buildNameplates()
		)--end fn
		
		fn updateList =
		(
			names = for np in self.nameplates collect np.name
			lbx_names.items = names 
		)--end fn
		
		fn updateGui =
		(
			updateFactory()
			updateNameplates()
			updateList()
		)--end fn
		

		-- this fn replaces the "on open do" handler and is responsible to make the rollout aware of the struct instance
		fn init pself = 
		(
			self = pself
			-- when assigning the header image, make sure to set gamma to 1.0 first and reset afterwards
			self.fileinGammaDecorator (fn setHeaderImg=(imgTag_header.bitmap = openBitmap headerImgPth))
			updateGui()
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
				updateGui()
			)
			else ckb_objects.checked=True
		)--end on
		
		on ckb_materials changed state do
		(
			if state then
			(
				updateCheckbuttons ckb_materials
				updateGui()
			)
			else ckb_materials.checked=True
		)--end on
		
		on ckb_layers changed state do
		(
			if state then
			(
				updateCheckbuttons ckb_layers
				updateGui()
			)
			else ckb_layers.checked=True
		)--end on
		
		on ckb_files changed state do
		(
			if state then
			(
				updateCheckbuttons ckb_files
				updateGui()
			)
			else ckb_files.checked=True
		)--end on
		
		on rdo_source changed state do
		(
			updateGui()
		)--end on
		
		on btn_rename pressed do 
		(			
			self.constructNewNames self.nameplates
			updateList()
		)--end on

	)--end rollout
	,
	fn show = 
	(	
		createDialog ro
		ro.init self
		-- for some reason we must set it here, setting it as default in the rollout would disable it forever
		ro.dn_textbox_folder.enabled = False
	)--end fn
	,
	fn close = 
	(
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