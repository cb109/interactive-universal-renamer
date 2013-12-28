/**
	Post-Installation dialog with the option to open the folder where everythign was placed.
	The macro file is placed by the mzp.run, but also executed from here once so it can be used
	right after installation without having to restart 3ds Max.
*/

try(destroyDialog roInstalled)catch()
rollout roInstalled "Interactive Renamer" width:191 height:95
(
	local dir = getDir #userScripts + "\\interactiveRenamer"

	label lbl1 "Installation successful.\n\nTo use: Customize User Interface, category \"Buelter\""	pos:[5,5] width:200 height:56
	button btnDir "directory" pos:[139,74] width:48 height:16
	label lbl2 "-----------------------------------------------------------" pos:[-1,60] width:192 height:8
	label lbl3 "To deinstall, just delete the " pos:[5,75] width:133 height:18

	on btnDir pressed do
	(
		shellLaunch dir ""
	)--end on
	
	on roInstalled open do
	(
		try
		(
			fileIn (getDir #usermacros + "\\Buelter-interactiveRenamer_macro.mcr")
		)
		catch (print "Buelter-interactiveRenamer.mcr not found")
			
	)--end on
	
)
createDialog roInstalled