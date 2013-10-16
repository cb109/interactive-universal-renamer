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
	fn setRefName=()
)--end struct

struct ObjectNameplate
(
	id = undefined,
	name = undefined,
	newName = undefined,
	ref = undefined,

	fn getNameFromRef =
	(
		name = ref.name
	),

	fn setRefName = 
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
		name = ref.name
	),

	fn setRefName = 
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
		name = ref.name
	),

	fn setRefName = 
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

struct FileNameplate
(
	id = undefined,
	name = undefined,
	newName = undefined,
	ref = undefined,

	fn getNameFromRef =
	(
		name = getFileNameFile ref
	),

	fn setRefName = 
	(
		newFileName = newName + (getFileNameType ref)
		HiddenDOSCommand ("rename " + "\"" + ref + "\"" + " " + "\"" + newFileName + "\"") --quot marks are needed for paths with blank spaces
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
	fn collectRefs =
	(
		fn collectObjectRefs=()
		fn collectMaterialRefs=()
		fn collectLayerRefs=()
		fn collectFileRefs=()
	),
	fn buildNameplates=()
)--end struct

struct NameplateFactory
(
	type = undefined, -- "objects", "materials", "layers", "files"
	mode = undefined, -- "selection" or "scene"
	refs = #(), -- node references
	
	nested = true, -- only for materials mode. if true, get nested materials
	dir = "", -- only for files mode. get all files from this folder as refs

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
							HelperFunctions.getNestedMaterialsRecursive s.material refs
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
			refs = for i=0 to (LayerManager.count-1) collect (LayerManager.getLayer i)
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