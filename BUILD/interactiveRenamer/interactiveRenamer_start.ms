fileIn "interactiveRenamer.ms"

-- Global accessor for script. Must be defined prior to the struct to be used by callbacks!
global gInteractiveRenamer 

try(gInteractiveRenamer.close())catch()
gInteractiveRenamer = InteractiveRenamer()
gInteractiveRenamer.self = gInteractiveRenamer
gInteractiveRenamer.show()