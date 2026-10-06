## Overview
Simplified Arkanoid clone written in MIPS assembly for the MARS 4.5 simulator. The game is drawn on the Bitmap Display and controlled through the Keyboard and Display MMIO Simulator.

## Features
* Paddle controlled with **a** / **d**, with limits at both screen margins
* 90 blocks arranged in 3 rows of 30, each row with its own color
* Ball with diagonal movement that bounces off the walls, the paddle and the blocks, handling side, vertical and corner hits
* Lives system (5 lives) shown as red cells in the top row of the display
* Progressive difficulty: the ball speeds up every 3 paddle bounces
* Sound effects
<p align = "center">
  <img width="254" height="254" alt="arkanoid" src="https://github.com/user-attachments/assets/29d5281b-6c8f-4f4a-b6bc-5243552553f5" />
</p>

## Technologies
* MIPS assembly
* MARS 4.5

## How to play
1. Open the `.asm` file in MARS 4.5
2. Open **Tools → Bitmap Display** and configure it as follows:
   * Unit width in pixels: `8`
   * Unit height in pixels: `8`
   * Display width in pixels: `256`
   * Display height in pixels: `256`
   * Base address for display: `0x10010000 (static data)`
3. Click **Connect to MIPS**
4. Open **Tools → Keyboard and Display MMIO Simulator** and click **Connect to MIPS**
5. Assemble and run the program (**Run → Assemble**, then **Run → Go**)
6. Click on the lower input rectangle ("KEYBOARD") of the MMIO Simulator window so that the key presses are received
7. Move the paddle with **a** / **d**
