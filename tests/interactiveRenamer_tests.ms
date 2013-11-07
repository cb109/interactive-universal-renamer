/***
	Tests most renaming functions. Does not test the GUI.
***/

-- Import files
tokens = filterString (getThisScriptFilename()) "\\"
pth = tokens[1]
for i=2 to (tokens.count-2) do 
	pth += "\\"+tokens[i]
	
fileIn (pth+"\\nameplates.ms")
fileIn (pth+"\\interactiveRenamer.ms")
	
testfiles = #(
	"foobar_01.jpg", "foobar_02.exr", "foobar_03.bmp", "foobar_04.mp3"
)
testobjects = #()
testlayers = #()
	
fn setUp =
(	
	-- Create some objects, layers and materials
	for i=1 to 4 do
	(
		s = Sphere()
		p = Point()
		append testobjects s
		append testobjects p
		s.material = Standard()
		l = LayerManager.newLayer()
		append testlayers l
	)--end for
	
	-- Create some files
	for f in testfiles do
		HiddenDOSCommand ("type NUL > \""+pth+"\\tests\\"+f+"\"")
	
	-- Create an asset
	testobjects[1].material.diffuseMap = Bitmaptexture filename:(pth+"\\tests\\"+testfiles[1])
)--end fn

fn tearDown =
(
	for f in testfiles do
		HiddenDOSCommand ("DEL \""+pth+"\\tests\\"+f+"\"")
	for o in testobjects do 
		delete o
	for l in testlayers do
		LayerManager.deleteLayerByName l.name
	testfiles=testobjects=testlayers=undefined
)--end fn


fn testObjectRenaming =
(

)--end fn

fn testMaterialRenaming =
(
	
)--end fn

fn testLayerRenaming =
(
	
)--end fn

fn testAssetRenaming =
(
	
)--end fn

fn testFileRenaming =
(
)--end fn

fn run =
(
	
)--end fn

-- Execute tests
setUp()
run()
tearDown()