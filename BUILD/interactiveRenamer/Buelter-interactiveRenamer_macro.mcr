macroscript interactiveRenamer
category:"Buelter"
buttontext:"Interactive Renamer"
(
	dir = getDir #userScripts + "\\interactiveRenamer"
	script = dir + "\\interactiveRenamer_start.ms"
	
	if doesFileExist script then
		fileIn script
	else
		messagebox ("The script folder was not found in:\n\n" + (getDir #userScripts)) title:"Interactive Renamer"
)