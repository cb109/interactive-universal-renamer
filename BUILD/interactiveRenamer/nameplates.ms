struct AbstractNameplate
(
	/**
		Stores name-reference-correlation
		and uses type-corresponding methods to 
		get/set reference name.
	**/
	id, 
	name, 
	newName, 
	ref, 
	fn getNameFromRef=(), 
	fn assignNameToRef=()
)--end struct

struct ObjectNameplate
(
	id = undefined,
	name = undefined,
	newName = undefined,
	ref = undefined,

	fn getNameFromRef =
	(
		name = newName = ref.name
	),

	fn assignNameToRef = 
	(
		ref.name = newName
	)
)--end struct

struct MaterialNameplate
(
	id = undefined,
	name = undefined,
	newName = undefined,
	ref = undefined,

	fn getNameFromRef =
	(
		name = newName = ref.name
	),

	fn assignNameToRef = 
	(
		ref.name = newName
	)
)--end struct

struct LayerNameplate
(
	id = undefined,
	name = undefined,
	newName = undefined,
	ref = undefined,

	fn getNameFromRef =
	(
		name = newName = ref.name
	),

	fn assignNameToRef = 
	(
		local layManClosed = false
		if (LayerManager.isDialogOpen()) do -- if open, close to make changes committ
		(
			LayerManager.closeDialog()
			layManClosed = true
		)--end if
		-- remember that layer names have to be unique or renaming is omitted 
		ref.setName newName
		if layManClosed do macros.run "Layers" "LayerManager" -- reopen (there is no .openDialog() so use this)
	)
)--end struct

struct AssetNameplate
(
	id = undefined,
	name = undefined,
	newName = undefined,
	ref = undefined,
	
	fn getNameFromRef = 
	(
		name = newName = ref
	), 
	
	fn assignNameToRef = 
	(
		ATSOps.ClearSelection()
		ATSOps.SelectFiles #(name)
		ATSOps.RetargetSelection newName
	)
)--end struct

struct FileNameplate
(
	id = undefined,
	name = undefined,
	newName = undefined,
	ref = undefined,

	fn getNameFromRef =
	(
		name = newName = (getFileNameFile ref) + (getFilenameType ref)
	),

	fn assignNameToRef = 
	(
		HiddenDOSCommand ("rename " + "\"" + ref + "\"" + " " + "\"" + newName + "\"") --quot marks are needed for paths with blank spaces
	)
)--end struct

struct AbstractNameplateFactory
(
	/**
		Use as Singleton, build one instance of this only.
		Creates Nameplate-Objects to store name-reference-correlations
		and use the corresponding methods to get/set the reference name.
	**/
	type, 
	mode, 
	refs,
	nested, 
	dir, 
	-- Add helper functions here as needed,
	fn collectRefs =
	(
		fn collectObjectRefs=()
		fn collectMaterialRefs=()
		fn collectLayerRefs=()
		fn collectAssetRefs=()
		fn collectFileRefs=()
	),
	fn buildNameplates=()
)--end struct

struct NameplateFactory
(
	type = undefined, -- "objects", "materials", "layers", "assets", "files"
	mode = undefined, -- "selection" or "scene"
	refs = #(), -- node references
	
	nested = false, -- only for materials mode. if true, get nested materials
	dir = "", -- only for files mode. get all files from this folder as refs

	fn getNestedMaterialsRecursive theMat arr=
	(		
		/***	Tries to collect all materials that are nested inside a base material recursively.
			Supports an arbitrary number of materials that can have nested materials inside them
			@param	theMat	The base material.
			@param	arr	The array that all found materials are appended to.
		***/
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
	fn collectRefs =
	(
		refs = #()
		fn collectObjectRefs =
		(
			refs = #()
			case mode of
			(
				"selection": refs = for s in selection collect s					
				"scene": refs = for o in objects collect o
			)--end case
			refs -- return
		)--end fn

		fn collectMaterialRefs =
		(
			refs = #()
			case mode of
			(
				"selection": 
				(				
					for s in selection where s.material != undefined do
					(
						if nested then -- get all nested materials as well
						(
							-- Referring to global accessor of script here; maybe move function to this file
							getNestedMaterialsRecursive s.material refs
						)
						else -- only get base materials
						(
							appendIfUnique refs s.material
						)--end else
					)--end for
				)
				"scene": 
				(
					-- get all materials by class
					local matClasses = material.classes
					for mc in matClasses do
					(
						local instances = getClassInstances mc
						join refs instances
					)--end for
				)
			)--end case
			refs -- return
		)--end fn

		fn collectLayerRefs =
		(
			refs = #()
			case mode of
			(
				"selection": for s in selection do appendIfUnique refs (LayerManager.getLayerFromName s.layer.name)
				"scene": refs = for i=0 to (LayerManager.count-1) collect (LayerManager.getLayer i)
			)--end case
			refs -- return
		)--end fn
		
		fn collectAssetRefs =
		(
			refs = #()
			-- Inital refresh needed to detect files
			ATSOps.Refresh()
			ATSOps.GetFiles &refs
			refs -- return
		)--end fn

		fn collectFileRefs =
		(
			refs = #()
			if dir != "" do
				refs = sort (getFiles (dir + "\\" + "*.*"))
			refs -- return
		)--end fn

		-- collection happens here using our sub-functions
		case type of
		(
			"objects": refs = collectObjectRefs()
			"materials": refs = collectMaterialRefs()
			"layers": refs = collectLayerRefs()
			"assets": refs = collectAssetRefs()
			"files": refs = collectFileRefs()
		)--end case
		refs -- return
	),--end fn

	fn buildNameplates =
	(
		nameplates = #()
		id = 0
		for ref in refs do
		(
			np = undefined
			id += 1
			case type of
			(
				"objects": np = (ObjectNameplate id:id name:"" newName:"" ref:ref)
				"materials": np = (MaterialNameplate id:id name:"" newName:"" ref:ref)
				"layers": np = (LayerNameplate id:id name:"" newName:"" ref:ref)
				"assets": np = (AssetNameplate id:id name:"" newName:"" ref:ref)
				"files": np = (FileNameplate id:id name:"" newName:"" ref:ref)
			)--end case
			np.getNameFromRef()
			append nameplates np
		)--end for
		nameplates -- return
	)--end fn
)--end struct

-- workflow:
-- 1. create factory and specify type and mode
-- 2. let it collect references from scene or selection
-- 3. build nameplates from references and initialize them

-- example:
-- test = NameplateFactory type:"files" mode:"scene" nested:true
-- test.dir = @"C:\Users\Christoph\Desktop\2013 UI ordner"
-- test.collectRefs()
-- nps = test.buildNameplates()
-- print nps

"imported nameplates.ms"