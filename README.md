# Dreamcast Burner for macOS

This project will attempt to be a solution to burn Dreamcast CDI image files to CD on modern macOS, since currently no solution exists.  This program is functional but only works with smaller games as of now.  Please note, this only works on Dreamcast CDI images, and not any generic CDI images.

## Usage
`DreamcastBurner.app/dreamcast_burner <cdi image> [--print-tracks]`
- `<cdi image>` -- The image to burn
- `--print-tracks` -- Prints information, such as number of tracks in the image and their length.

Please note, you MUST run the `dreamcast_burner` executable from a `*.app` folder, otherwise the program will not be able to detect your CD burner.  I have no idea why this is.

Instead of running the exectuable directly, you run Dreamcast Burner with `./build.sh run`.

## Requirements
- macOS.  Tested on macOS Monterey, but I'm sure it will work on earlier version.
- [Odin](https://odin-lang.org) compiler.
- Xcode.
- CD Burner.
- Dreamcast to play the games!

## Compile
- Run `./build.sh`

## Tested Games
### Working
- Xenocrisis
- [VVVVVV](https://github.com/gusarba/VVVVVVDC)
- ChuChu Rocket

### Not Working
- Sonic Adventure 2
- Jet Grind Radio
- Crazy Taxi
- Street Fighter 3
- Marvel vs Capcom 2

## Credits
Big thanks to kazade's [mkdcdisc](https://gitlab.com/simulant/mkdcdisc/-/tree/main) for helping me write the CDI parsing code!