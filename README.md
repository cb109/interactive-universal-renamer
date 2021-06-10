# Interactive Universal Renamer

This is a renaming script for 3ds Max with live preview and support for objects, layers, materials and files.

See an (older) demonstration video: https://vimeo.com/57767912

## How to install via .mzp

The repository should include a `InteractiveRenamer_v2.20.mzp` file: Download and drag-and-drop it into your 3ds Max viewport to install the tool.

### How to build the .mzp

The installation uses the mzpbuilder script from [Klaas Nienhuis](http://www.klaasnienhuis.nl/).

- Open `builder/mzpbuilder.ms` in a text editor and modify line 57 `theIniFile` to point to your local `builder/mzpbuilder.ini`.
- Also open the `builder/mzpbuilder.ini` and update paths as needed to match your local files.
- Run `mzpbuilder.ms` in 3ds Max, you will find a new `.mzp` file in the `build/` folder afterwards.
- That `.mzp` file can be drag-and-dropped into 3ds Max to install the tool.

## How to install manually

- Navigate to your user scripts folder. You can get the location inside 3ds Max by evaluating the following MAXScript: `getDir #userScripts`. It should be something like: `"C:\Users\<username>\AppData\Local\Autodesk\3dsMax\<version>- 64bit\ENU\scripts"`
- Create a folder there named `interactiveRenamer`.
- Copy the following files to that folder:
  - `interactiveRenamer_header.png`
  - `interactiveRenamer_installed.ms`
  - `interactiveRenamer.ms`
  - `nameplates.ms`
- Drag-and-drop the `Buelter-interactiveRenamer_macro.mcr` into your 3ds Max viewport to install a macro to launch the tool.
- You can add the macro script to a quad menu/toolbar button etc. via Customize User Interface > Category: "Buelter"

## Known Issues

- File renaming support is very basic and known to have issues with whitespaces in filenames.
- The "nested materials" have been implemented to support what was available in 2013. "Newer" multi materials etc. are not supported.
