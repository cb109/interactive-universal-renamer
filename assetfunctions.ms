struct AssetFunctions (
	/***Offers functions to collect, manipulate and
	update assets from and to a saved 3ds Max file.

	Uses the AssetManager struct as backend in 3ds Max.

	***/
	private

	errorSaveFirst = "ERROR - AssetEditor - File needs to be saved " + \
		"before working with assets.",

	fn _matchesFileName asset fileName = (
		asset.resolvedFileName == fileName or asset.fileName == fileName
	),


	public

	fn getSceneFile = (
		sceneFile = maxFilePath + maxFileName

		if sceneFile == "" do (
			print this.errorSaveFirst
			return False
		)

		sceneFile
	),

	fn getAssets sceneFile: = (
		if sceneFile == unsupplied do
			sceneFile = this.getSceneFile()
		getMAXFileAssetMetadata sceneFile
	),

	fn getAssetById id = (
		for asset in this.getAssets() do (
			if asset.assetId == id do
				exit with asset
		)
		undefined
	),

	fn getAssetsByType type = (
		assets = this.getAssets()
		for asset in assets where asset.type == type as Name
			collect asset
	),

	fn getAssetsByFileName fileName = (
		for asset in assets where this._matchesFileName asset fileName
			collect asset
	),

	fn updateAssets assets: = (
		if assets == unsupplied do
			assets = this.getAssets()
		sceneFile = this.getSceneFile()
		setMAXFileAssetMetadata sceneFile assets
	),

	fn updateFileNameOnAssets oldFileName newFileName = (
		assets = this.getAssetsByFileName oldFileName
		sceneFile = this.getSceneFile()
		for asset in assets do
			asset.fileName = newFileName
		setMAXFileAssetMetadata sceneFile assets
	),

	fn printAssets = (
		for asset in this.getAssets() do (
			format "ID:% Type:% File:%\n" \
				asset.assetId asset.type asset.filename
		)
	)
)

AssetFunctions = AssetFunctions()