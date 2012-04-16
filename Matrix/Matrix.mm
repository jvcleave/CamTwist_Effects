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

// N O T E :
// This code is derived from the Matrix effect from EffectTV
// N O T E :

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


#import "Matrix.h"


#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "CTUtil.h"
#include "matrixFont.xpm"

#define MODE_NONE 0
#define MODE_FALL 1
#define MODE_STOP 2
#define MODE_SLID 3

static const float kern00 = -1;
static const float kern01 = -2;
static const float kern02 = -1;
static const float kern10 = 0;
static const float kern11 = 0;
static const float kern12 = 0;
static const float kern20 = 1;
static const float kern21 = 2;
static const float kern22 = 1;

#ifdef __BIG_ENDIAN
enum
{
	MATRIX_BLUE = 0,
	MATRIX_GREEN,
	MATRIX_RED,
	MATRIX_ALPHA,
};
#else
enum
{
	MATRIX_ALPHA = 0,
	MATRIX_RED,
	MATRIX_GREEN,
	MATRIX_BLUE,
};
#endif

inline unsigned char getColorComponent (unsigned value, int comp)
{
	unsigned char *bits = (unsigned char *) &value;
	return bits[comp];
}

inline void setColorComponent (unsigned *value, int comp, unsigned char pix)
{
	unsigned char *bits = (unsigned char *) value;
	bits[comp] = pix;
}

//////////////////////////////////////////////////////////////////////////

@implementation Matrix

+ (NSString *) name
{
	return @"Matrix";
}

#if 0
/* Create edge-enhanced image data from the input */
- (void) createImg:(RGB32 *) src
{
	unsigned int val;

	unsigned char * q = img;

	for(int y = 0; y < mapH; y++) {
		RGB32 *p = src;
		for(int x = 0; x < mapW; x++) {
			int pc = *p;
			int pr = *(p + FONT_W - 1);
			int pb = *(p + rowwords * (FONT_H - 1));

			pc >>= 8;
			pr >>= 8;
			pb >>= 8;

			int r = (int)(pc & 0xff0000) >> 15;
			int g = (int)(pc & 0x00ff00) >> 7;
			int b = (int)(pc & 0x0000ff) * 2;

			val = (r + 2*g + b) >> 5; // val < 64

			r -= (int)(pr & 0xff0000)>>16;
			g -= (int)(pr & 0x00ff00)>>8;
			b -= (int)(pr & 0x0000ff);
			r -= (int)(pb & 0xff0000)>>16;
			g -= (int)(pb & 0x00ff00)>>8;
			b -= (int)(pb & 0x0000ff);

			val += (r * r + g * g + b * b)>>5;

			if(val > 160)
				val = 160; // want not to make blip from the edge.
			*q = (unsigned char)val;

			p += FONT_W;
			q++;
		}
		src += rowwords * FONT_H;
	}
}
#else

#define MATRIX_MAP_VAL(map,x,y) (map[(y) * mapW + (x)])

- (void) scale:(RGB32 *) src
{
	RGB32 *v = src;
	for(int y = 0; y < mapH; y++) 
	{
		RGB32 *h = v;
		for(int x = 0; x < mapW; x++) 
		{
			RGB32 *p = h;
			int total = 0;
			for (int yy = 0; yy < FONT_H; yy ++)
			{
				for (int xx = 0; xx < FONT_W; xx ++)
				{
					int val = *p++;
					total += getColorComponent(val, MATRIX_RED) +
							 getColorComponent(val, MATRIX_GREEN) +
							 getColorComponent(val, MATRIX_BLUE);
				}
				p -= FONT_W;
				p += rowwords;
			}
			
			MATRIX_MAP_VAL(scaled, x, y) = total / FONT_W / FONT_H / 3;
			
			h += FONT_W;
		}
		
		v += FONT_H * rowwords;
	}
}

- (void) createImg:(RGB32 *) src
{
	[self scale:src];
	
	unsigned char * q = img;

	for (int y = 0; y < mapH; y++)  
	{
		for (int x = 0; x < mapW; x++) 
		{
			int accumH = 0;
			int accumV = 0;
			int SUM = 0;

			/* image boundaries */
			if (y == 0 || y == vheight - 1)
				SUM = 0;
			else if (x == 0 || x == vwidth - 1)
				SUM = 0;
			else   
			{
				unsigned char pixel;
				
				pixel = MATRIX_MAP_VAL(scaled, x - 1, y - 1);
				accumV += pixel*kern00;
				accumH += pixel*kern00;
				pixel = MATRIX_MAP_VAL(scaled, x, y - 1);
				accumV += pixel*kern01;
				accumH += pixel*kern10;
				pixel = MATRIX_MAP_VAL(scaled, x + 1, y - 1);
				accumV += pixel*kern02;
				accumH += pixel*kern20;
				pixel = MATRIX_MAP_VAL(scaled, x - 1, y);
				accumV += pixel*kern10;
				accumH += pixel*kern01;
				pixel = MATRIX_MAP_VAL(scaled, x, y);
				accumV += pixel*kern11;
				accumH += pixel*kern11;
				pixel = MATRIX_MAP_VAL(scaled, x + 1, y);
				accumV += pixel*kern12;
				accumH += pixel*kern21;
				pixel = MATRIX_MAP_VAL(scaled, x - 1, y + 1);
				accumV += pixel*kern20;
				accumH += pixel*kern02;
				pixel = MATRIX_MAP_VAL(scaled, x, y + 1);
				accumV += pixel*kern21;
				accumH += pixel*kern12;
				pixel = MATRIX_MAP_VAL(scaled, x + 1, y + 1);
				accumV += pixel*kern22;
				accumH += pixel*kern22;

				/*---GRADIENT MAGNITUDE APPROXIMATION (Myler p.218)----*/
				SUM = abs(accumV) + abs(accumH);
			}

			if (SUM > 255)
				SUM = 255;
			if (SUM < 0)
				SUM = 0;

			*q++ = SUM * 160 / 255;
		}
	}
}

#endif


#define WHITE 0.45
- (RGB32) green:(unsigned int) v
{
	unsigned int p = ~0;

	if (v < 256) 
	{
		setColorComponent(&p, MATRIX_RED, v * WHITE);
		setColorComponent(&p, MATRIX_GREEN, v);
		setColorComponent(&p, MATRIX_BLUE, v * WHITE);
		//return ((int)(v*WHITE)<<16)|(v<<8)|(int)(v*WHITE);
	}
	else
	{
		unsigned w = v - (int)(256*WHITE);
		if (w > 255) 
			w = 255;
		setColorComponent(&p, MATRIX_RED, w);
		setColorComponent(&p, MATRIX_GREEN, 255);
		setColorComponent(&p, MATRIX_BLUE, w);
		//return (w << 16) + 0xff00 + w;
	}
		
	return p;
}

- (void) setPalette
{
	unsigned int black = 0;

	setColorComponent(&black, MATRIX_ALPHA, 255);

	for(int i=0; i<256; i++) {
		palette[i*FONT_DEPTH  ] = black;
		palette[i*FONT_DEPTH+1] = [self green:(0x44 * i / 170)];
		palette[i*FONT_DEPTH+2] = [self green:(0x99 * i / 170)];
		palette[i*FONT_DEPTH+3] = [self green:(0xff * i / 170)];
	}
}

- (void) setPattern
{
	int c, l, x, y, cx, cy;
	char *p;
	unsigned char v;

	/* FIXME: This code is highly depends on the structure of bundled */
	/*        matrixFont.xpm. */
	for(l = 0; l < 32; l++) {
		p = matrixFont[5 + l];
		cy = l /4;
		y = l % 4;
		for(c = 0; c < 40; c++) {
			cx = c / 4;
			x = c % 4;
			switch(*p) {
				case ' ':
					v = 0;
					break;
				case '.':
					v = 1;
					break;
				case 'o':
					v = 2; 
					break;
				case 'O':
				default:
					v = 3;
					break;
			}
			font[(cy * 10 + cx) * FONT_W * FONT_H + y * FONT_W + x] = v;
			p++;
		}
	}
}

- (void) drawChar:(RGB32 *) dest
				c:(unsigned char) c
				v:(unsigned char) v
{
	int x, y, i;
	int *p;
	unsigned char *f;

	i = 0;
	if(v == 255) { // sticky characters
		v = 160;
	}

	p = &palette[(int)v * FONT_DEPTH];
	f = &font[(int)c * FONT_W * FONT_H];
	for(y=0; y<FONT_H; y++) {
		for(x=0; x<FONT_W; x++) {
			*dest++ = p[*f];
			f++;
		}
		dest += rowwords - FONT_W;
	}
}

- (void) darkenColumn:(int) x
{
	int y;
	unsigned char *p;
	int v;

	p = vmap + x;
	for(y=0; y<mapH; y++) {
		v = *p;
		if(v < 255) {
			v *= 0.9;
			*p = v;
		}
		p += mapW;
	}
}

- (void) blipNone:(int) x
{
	unsigned int r;

	// This is a test code to reuse a randome number for multi purpose. :-P
	// Of course it isn't good code because fastrand() doesn't generate ideal
	// randome numbers.
	r = rand();

	if((r & 0xff) == 0xff) {
		blips[x].mode = MODE_FALL;
		blips[x].y = 0;
		blips[x].speed = (r >> 30) + 1;
		blips[x].timer = 0;
	} else if((r & 0x0f000) ==  0x0f000) {
		blips[x].mode = MODE_SLID;
		blips[x].timer = (r >> 28) + 15;
		blips[x].speed = ((r >> 24) & 3) + 2;
	}
}

- (void) blipFall:(int) x
{
	int i, y;
	unsigned char *p, *c;
	unsigned int r;

	y = blips[x].y;
	p = vmap + x + y * mapW;
	c = cmap + x + y * mapW;

	for(i=blips[x].speed; i>0; i--) {
		if(blips[x].timer > 0) {
			*p = 255;
		} else {
			*p = 254 - i * 10;
		}
		*c = rand() % CHARNUM;
		p += mapW;
		c += mapW;
		y++;
		if(y >= mapH) break;
	}
	if(blips[x].timer > 0) {
		blips[x].timer--;
	}

	if(y >= mapH) {
		blips[x].mode = MODE_NONE;
	}

	blips[x].y = y;

	if(blips[x].timer == 0) {
		r = rand();
		if((r & 0x3f00) == 0x3f00) {
			blips[x].timer = (r >> 28) + 8;
		} else if(blips[x].speed > 1 && (r & 0x7f) == 0x7f) {
			blips[x].mode = MODE_STOP;
			blips[x].timer = (r >> 26) + 30;
		}
	}
}

- (void) blipStop:(int) x
{
	int y;

	y = blips[x].y;
	vmap[x + y * mapW] = 254;
	cmap[x + y * mapW] = rand() % CHARNUM;

	blips[x].timer--;

	if(blips[x].timer < 0) {
		blips[x].mode = MODE_FALL;
	}
}

- (void) blipSlide:(int) x
{
	int y, dy;
	unsigned char *p;

	blips[x].timer--;
	if(blips[x].timer < 0) {
		blips[x].mode = MODE_NONE;
	}

	p = cmap + x + mapW * (mapH - 1);
	dy = mapW * blips[x].speed;

	for(y=mapH - blips[x].speed; y>0; y--) {
		*p = *(p - dy);
		p -= mapW;
	}
	for(y=blips[x].speed; y>0; y--) {
		*p = rand() % CHARNUM;
		p -= mapW;
	}
}

- (void) updateCharMap
{
	int x;

	for(x=0; x<mapW; x++) {
		[self darkenColumn:x];
		switch(blips[x].mode) {
			default:
			case MODE_NONE:
				[self blipNone:x];
				break;
			case MODE_FALL:
				[self blipFall:x];
				break;
			case MODE_STOP:
				[self blipStop:x];
				break;
			case MODE_SLID:
				[self blipSlide:x];
				break;
		}
	}
}

//static int event(SDL_Event *event)
//{
//	if(event->type == SDL_KEYDOWN) {
//		switch(event->key.keysym.sym) {
//		case SDLK_SPACE:
//			memset(cmap, CHARNUM - 1, mapW * mapH * sizeof(unsigned char));
//			memset(vmap, 0, mapW * mapH * sizeof(unsigned char));
//			memset(blips, 0, mapW * sizeof(Blip));
//			pause = 1;
//			break;
//		case SDLK_1:
//		case SDLK_KP1:
//			mode = 0;
//			break;
//		case SDLK_2:
//		case SDLK_KP2:
//			mode = 1;
//			break;
//		default:
//			break;
//		}
//	} else if(event->type == SDL_KEYUP) {
//		if(event->key.keysym.sym == SDLK_SPACE) {
//			pause = 0;
//		}
//	}
//
//	return 0;
//}

- (void) draw:(RGB32 *) src
		 dest:(RGB32 *) dest
{
	int x, y;
	RGB32 *p, *q;
	unsigned char *c, *v, *i;
	unsigned int val;
	RGB32 a, b;

	[self updateCharMap];
	[self createImg:src];

	c = cmap;
	v = vmap;
	i = img;

	p = dest;
	for(y=0; y<mapH; y++) {
		q = p;
		for(x=0; x<mapW; x++) {
			val = *i | *v;
//			if(val > 255) val = 255;
			[self drawChar:q c:*c v:val];
			i++;
			v++;
			c++;
			q += FONT_W;
		}
		p += rowwords * FONT_H;
	}

	if(mode == 1) {
		for(x=0; x<video_area; x++) {
			a = *dest;
			b = *src++;
			b = (b & 0xfefeff) >> 1;
			*dest++ = a | b;
		}
	}
}

- (id) initWithContext:(CTContext *) ctContext
{
	self = [super initWithContext:ctContext];

	vwidth = [[self context] size].width;
	vheight = [[self context] size].height;
	
	scratch = [CTUtil CreateBitmapContextPixelsWide:vwidth pixelsHigh:vheight];
	
	rowwords = CGBitmapContextGetBytesPerRow(scratch) / 4;
	
	video_area = rowwords * vheight;
	
	mode = 0;
	
	mapW = vwidth / FONT_W;
	mapH = vheight / FONT_H;
	cmap = (unsigned char *) malloc(mapW * mapH);
	vmap = (unsigned char *) malloc(mapW * mapH);
	img = (unsigned char *) malloc(mapW * mapH);
	scaled = (unsigned char *) malloc(mapW * mapH);

	blips = (Blip *) malloc(mapW * sizeof(Blip));

	[self setPattern];
	[self setPalette];

	memset(cmap, CHARNUM - 1, mapW * mapH * sizeof(unsigned char));
	memset(vmap, 0, mapW * mapH * sizeof(unsigned char));
	memset(blips, 0, mapW * sizeof(Blip));

	stat = 1;

	return self;
}

- (id) initWithCoder:(NSCoder *) coder
{
	return [self init];
}

- (void) dealloc
{
	free (cmap);
	free (vmap);
	free (img);
	free (scaled);
	free (blips);
	
	free (CGBitmapContextGetData(scratch));
	CGContextRelease(scratch);
	
	[super dealloc];
}

- (void) doit
{
	int sdata[vwidth * vheight];
	[[self context] fetchOpenGLPixels:sdata rowBytes:vwidth * 4];
	
	int *ddata = (int *) CGBitmapContextGetData(scratch);
	
	[self draw:sdata dest:ddata];

	CGImageRef cgimg = CGBitmapContextCreateImage (scratch);
	CIImage *ciimg = [CIImage imageWithCGImage:cgimg];
	
	[[[self context] ciCtx] drawImage:ciimg atPoint:CGPointZero fromRect:[ciimg extent]];
	
	CGImageRelease(cgimg);
}

@end
