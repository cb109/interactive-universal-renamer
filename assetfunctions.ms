struct AssetFunctions (
	/***Offers functions to collect, manipulate and
	update assets from and to a saved 3ds Max file.

	Uses the AssetManager struct as backend in 3ds Max.

	The update functions update both resolved and display filename,
	with the display filename being simply the file part and extension.

	***/
	private

	errorSaveFirst = #(
		"ERROR - AssetEditor - File needs to be saved " + \
		"before working with assets.",
		"Save file first"
	),

	public

	fn getSceneFile dialog:True = (
		sceneFile = maxFilePath + maxFileName

		if sceneFile == "" do (
			print this.errorSaveFirst[1]
			if dialog do
				messageBox this.errorSaveFirst[1] title:this.errorSaveFirst[2]
			sceneFile = undefined
		)

		sceneFile
	),

	fn getAssets sceneFile: = (
		if sceneFile == unsupplied do
			sceneFile = this.getSceneFile()
		if sceneFile == undefined do
			return #()
		getMAXFileAssetMetadata sceneFile
	),

	fn getAssetById id = (
		for asset in this.getAssets() do (
			if asset.assetId == id do
				return asset
		)
		undefined
	),

	fn getAssetsByType type = (
		assets = this.getAssets()
		for asset in assets where asset.type == type as Name
			collect asset
	),

	fn findAssetMatchingFileName fileName = (
		assets = this.getAssets()
		for i=1 to assets.count do (
			asset = assets[i]
			if asset.resolvedFileName == fileName do
				return asset
		)
		undefined
	),

	fn updateAssets assets: = (
		if assets == unsupplied do
			assets = this.getAssets()
		sceneFile = this.getSceneFile()
		if sceneFile != undefined do (
			setMAXFileAssetMetadata sceneFile assets
			True
		)
		False
	),

	fn updateAssetFileName oldFileName newFileName = (
		/***Updates the asset matching the old file name by changing
		the asset in the array and applying the array back to file.

		Input filenames should be absolute paths, since they are compared
		to the resolved filenames of the assetmetadata struct instances.

		***/
		assets = this.getAssets()
		asset = this.findAssetMatchingFileName oldFileName
		if asset != undefined do (
			asset.resolvedFileName = newFileName
			asset.fileName = fileNameFromPath newFileName
			this.updateAssets assets:assets
			return True
		)
		False
	),

	fn print = (
		for asset in this.getAssets() do (
			format "ID:% Type:% File:% Resolved:%\n" \
				asset.assetId asset.type asset.fileName asset.resolvedFileName
		)
	)
)

AssetFunctions = AssetFunctions()