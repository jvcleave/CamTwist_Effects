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


#import "EmptyEffect.h"


#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "CTUtil.h"




//////////////////////////////////////////////////////////////////////////

@implementation EmptyEffect

+ (NSString *) name
{
	return @"EmptyEffect";
}


- (void) draw:(RGB32 *) src
		 dest:(RGB32 *) dest
{
	int x, y;
	RGB32 *p, *q;
	unsigned char *i;
	unsigned int val;
	RGB32 a, b;


	i = img;

	p = dest;
	for(y=0; y<mapH; y++) 
	{
		q = p;
		for(x=0; x<mapW; x++) 
		{
			val = *i;
			i++;
			q += FONT_W;
		}
		p += rowwords * FONT_H;
	}
	mode = 1;
	if(mode == 1) {
		for(x=0; x<video_area; x++) {
			a = *dest;
			b = *src++;
			b = (b & 0xfefeff) >> 1;
			//*dest++ = a | b;
			*dest++ =rand()% 128;
		}
	}
}

- (id) initWithContext:(CTContext *) ctContext
{
	self = [super initWithContext:ctContext];

	videoWidth = [[self context] size].width;
	videoHeight = [[self context] size].height;
	
	scratch = [CTUtil CreateBitmapContextPixelsWide:videoWidth pixelsHigh:videoHeight];
	
	rowwords = CGBitmapContextGetBytesPerRow(scratch) / 4;
	
	video_area = rowwords * videoHeight;
	
	mode = 0;
	
	mapW = videoWidth / FONT_W;
	mapH = videoHeight / FONT_H;

	img = (unsigned char *) malloc(mapW * mapH);
	scaled = (unsigned char *) malloc(mapW * mapH);


	
	stat = 1;

	return self;
}

- (id) initWithCoder:(NSCoder *) coder
{
	return [self init];
}

- (void) dealloc
{

	free (img);
	free (scaled);
	
	free (CGBitmapContextGetData(scratch));
	CGContextRelease(scratch);
	
	[super dealloc];
}

- (void) doit
{
	int sdata[videoWidth * videoHeight];
	[[self context] fetchOpenGLPixels:sdata rowBytes:videoWidth * 4];
	
	int *ddata = (int *) CGBitmapContextGetData(scratch);
	
	[self draw:sdata dest:ddata];

	CGImageRef cgimg = CGBitmapContextCreateImage (scratch);
	CIImage *ciimg = [CIImage imageWithCGImage:cgimg];
	
	[[[self context] ciCtx] drawImage:ciimg atPoint:CGPointZero fromRect:[ciimg extent]];
	
	CGImageRelease(cgimg);
}

@end
