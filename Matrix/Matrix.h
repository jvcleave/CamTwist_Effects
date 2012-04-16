/*
    Matrix
    Copyright (C) 2007 Steve Green

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

// This code is derived from the Matrix effect from EffectTV

/*
 * EffecTV - Realtime Digital Video Effector
 * Copyright (C) 2001-2006 FUKUCHI Kentaro
 *
 * matrixTV - A Matrix Like effect.
 * This plugin for EffectTV is under GNU General Public License
 * See the "COPYING" that should be shiped with this source code
 * Copyright (C) 2001-2003 Monniez Christophe
 * d-fence@swing.be
 *
 * 2003/12/24 Kentaro Fukuchi
 * - Completely rewrote but based on Monniez's idea.
 * - Uses edge detection, not only G value of each pixel.
 * - Added 4x4 font includes number, alphabet and Japanese Katakana characters.
 */
 
#import "CTEffect.h"

typedef int RGB32;

typedef struct {
	int mode;
	int y;
	int timer;
	int speed;
} Blip;

#define CHARNUM 80
#define FONT_W 4
#define FONT_H 4
#define FONT_DEPTH 4

@interface Matrix : CTEffect 
{
  @public
	int vwidth;
	int vheight;
	int rowwords;
	int video_area;

	int stat;
	int mode;
	unsigned char font[CHARNUM * FONT_W * FONT_H];
	unsigned char *cmap;
	unsigned char *vmap;
	unsigned char *scaled;
	unsigned char *img;
	int mapW, mapH;
	RGB32 palette[256 * FONT_DEPTH];

	Blip *blips;
	
	CGContextRef scratch;
}

@end
