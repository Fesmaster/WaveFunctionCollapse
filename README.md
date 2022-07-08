# Wave Function Collapse
An algorithm to take a sample image and generate a large repeating image that is similar to it.

This algorithm is a reimplementation of the version found at [https://github.com/mxgmn/WaveFunctionCollapse](https://github.com/mxgmn/WaveFunctionCollapse). It was implemented from the general description, and thus works in a slightly different way. 

The basic algorithm idea is the same, and is presented below, along with some terminology.

## Running this program
This program is written in [Lua](https://www.lua.org/) for the [Love2D](https://love2d.org/) game engine. You will need Love2D to be able to run it. Love2D's executables are assumed to be on the system Path.

To run it, from the folder containing the code files, run `lovec . <yourInputFileHere> <optionalSwatchSizeHere>
- The input file (an image) is necessary
- The swatch size option is a number, and not necessary. Feel free to play around with it, but numbers < 3 are a bit broken, and numbers > 3 are really, really slow.

Due to its interaction with files passed on the command line, no .love files can be made at this time.

## Algorithm and Terminology
The pattern is the input image.

The Map is the output image.

A "swatch" is a bit of the input pattern, a square NxN pattern. For the purposes of this implementation, N = 3. (other numbers results in a bit of a mess with this implementation.) This is different from the original version linked above where the pattern (swatch) was usually 1x2, and had symmetry rules. The swatch is centered on its position, favoring negative values when N is even.

1. Read in the pattern and for every pixel (tile, voxel) make a NxN swatch. Store the unique swatches in a list.
2. Create a rectangle for the Map, and each cell of it holds a list of possible swatches. (or swatch ids, a bitfield representing possible swatches, etc.) This is a completely unobserved state.
3. Repeat the following steps:
	1. Collapse
		1. pick a random cell from the list of cells with more than 1 possible swatch. If none are found, go to step 4
		2. collapse the wave function, making it Only able to be that swatch.
	2. Propagate
		1. Use this information to update the nearby cells, removing newly impossible swatches from their lists.
		2. if a cell cannot be any swatch, employ and error correcting technique.
4. Now all the cells have only 1 possible swatch, and the map is completely observed. It is your output. Depending on the error correcting technique, there may be cells with 0 possible swatches, in this case, start over from scratch, or output nothing. 

There are several error correcting techniques that are possible. One, from [https://trasevol.dog/2017/09/01/di19/](https://trasevol.dog/2017/09/01/di19/) suggests using a stack of maps, and, when an error is detected, go back, mark the collapse you just made as impossible, and try again. After experimenting with this, I did not like it, as there were cases where it would entirely restart the generation.

Instead, the solution used here is to erase (mark completely unobserved) the broken cell and the NxN are around it, as well as the most recently collapsed cell and the NxN are around it, and continue the propagation from there.

---
## External Work

- `inspect.lua` is from [https://github.com/kikito/inspect.lua/tree/b611db6bfa9c12ce35dd4972032fbbd2ad5ba965](https://github.com/kikito/inspect.lua/tree/b611db6bfa9c12ce35dd4972032fbbd2ad5ba965), and under the MIT License (see the top of that file). It is used for dumping text versions of tables to the console, for debugging.