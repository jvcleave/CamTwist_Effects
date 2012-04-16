/*
    Flame
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
// This code is derived from the Flame hack in xscreensaver.  Original copyrights follow
// N O T E :

/* xflame, Copyright (c) 1996-2002 Carsten Haitzler <raster@redhat.com>
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation.  No representations are made about the suitability of this
 * software for any purpose.  It is provided "as is" without express or 
 * implied warranty.
 */

/* Version history as near as I (jwz) can piece together:

   * Carsten Haitzler <raster@redhat.com> wrote the first version in 1996.

   * Rahul Jain <rahul@rice.edu> added support for TrueColor displays.

   * Someone did a rough port of it to use the xscreensaver utility routines
     instead of creating its own window by hand.

   * Someone (probably Raster) came up with a subsequent version that had
     a Red Hat logo hardcoded into it.

   * Daniel Zahn <stumpy@religions.com> found that version in 1998, and 
     hacked it to be able to load a different logo from a PGM (P5) file, 
     with a single hardcoded pathname.

   * Jamie Zawinski <jwz@jwz.org> found several versions of xflame in
     March 1999, and pieced them together.  Changes:

       - Correct and fault-tolerant use of the Shared Memory extension;
         previous versions of xflame did not work when $DISPLAY was remote.

       - Replaced PGM-reading code with code that can read arbitrary XBM
         and XPM files (color ones will be converted to grayscale.)

       - Command-line options all around -- no hardcoded pathnames or
         behavioral constants.

       - General cleanup and portability tweaks.

   * 4-Oct-99, jwz: added support for packed-24bpp (versus 32bpp.)
   * 16-Jan-2002, jwz: added gdk_pixbuf support.

 */

/* portions by Daniel Zahn <stumpy@religions.com> */


#import "Flame.h"
#import "CTUtil.h"

//////////////////////////////////////////////////////////////////////////

#ifdef __BIG_ENDIAN
enum
{
	FLAME_BLUE = 0,
	FLAME_GREEN,
	FLAME_RED,
	FLAME_ALPHA,
};
#else
enum
{
	FLAME_ALPHA = 0,
	FLAME_RED,
	FLAME_GREEN,
	FLAME_BLUE,
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

static const float kern00 = -1;
static const float kern01 = -2;
static const float kern02 = -1;
static const float kern10 = 0;
static const float kern11 = 0;
static const float kern12 = 0;
static const float kern20 = 1;
static const float kern21 = 2;
static const float kern22 = 1;

//////////////////////////////////////////////////////////////////////////

@implementation Flame

+ (NSString *) name
{
	return @"FlameOn";
}

- (id) initWithContext:(CTContext *) ctContext
{
	self = [super initWithContext:ctContext];
	
	[self xflame_init];

	return self;
}

- (id) initWithCoder:(NSCoder *) coder
{
	self = [super initWithCoder:coder];
	
	[self xflame_init];

	return self;
}

- (void) dealloc
{
	free (CGBitmapContextGetData(scratch));
	CGContextRelease(scratch);

	free (flame);
	free (scaled);
	free (sobeled);
	
	[super dealloc];
}

- (void) InitColors
{
	// FFAF5F
	int rr = 0xff;
	int gg = 0xaf;
	int bb = 0x5f;
	
	int red   = 255 - rr;
	int green = 255 - gg;
	int blue  = 255 - bb;

	int j = 0;
	for (int i = 0; i < 256 * 2; i += 2)
    {
		int r = (i - red)   * 3;
		int g = (i - green) * 3;
		int b = (i - blue)  * 3;

		if (r < 0)   r = 0;
		if (r > 255) r = 255;
		if (g < 0)   g = 0;
		if (g > 255) g = 255;
		if (b < 0)   b = 0;
		if (b > 255) b = 255;

		int a = (r + g + b) / 3;
		
		unsigned c;
		unsigned char *bits = (unsigned char *) &c;
		bits [FLAME_RED] = r;
		bits [FLAME_GREEN] = g;
		bits [FLAME_BLUE] = b;
		bits [FLAME_ALPHA] = a;
		
		ctab[j++] = c;
    }
}

- (void) InitFlame
{
	fwidth  = width / 2;
	fheight = height / 2;
	flame   = (unsigned char *) malloc((fwidth + 2) * (fheight + 2)
									 * sizeof(unsigned char));
	scaled  = (unsigned char *) malloc((fwidth) * (fheight)
									 * sizeof(unsigned char));
	sobeled = (unsigned char *) malloc((fwidth) * (fheight)
									 * sizeof(unsigned char));

	top      = 1;
	ihspread  = 30;
	ivspread  = 97;
	iresidual = 99;
	variance  = 50;
	vartrend  = 20;
	bloom     = NO;

	hspread = ihspread;
	vspread = ivspread;
	residual = iresidual;
}

unsigned char blit (unsigned char oldb, unsigned char newb, int a)
{
	int diff = (int) newb - (int) oldb;
	return oldb + diff * a / 255;
}

- (void) setPixel:(unsigned *) ptr
			value:(unsigned) value
{
	unsigned oldValue = *ptr;
	
	unsigned char *oldBits = (unsigned char *) &oldValue;
	unsigned char *newBits = (unsigned char *) &value;
	
	unsigned a = newBits[0];
	
	newBits[FLAME_RED] = blit (oldBits[FLAME_RED], newBits[FLAME_RED], a);
	newBits[FLAME_GREEN] = blit (oldBits[FLAME_GREEN], newBits[FLAME_GREEN], a);
	newBits[FLAME_BLUE] = blit (oldBits[FLAME_BLUE], newBits[FLAME_BLUE], a);
	newBits[FLAME_ALPHA] = 255;
	
	*ptr = value;
}

- (void) Flame2Image32
{
	unsigned char *baseptr = (unsigned char *) CGBitmapContextGetData(scratch);
	unsigned int rowbytes = CGBitmapContextGetBytesPerRow(scratch);
	
	unsigned char *ptr1 = flame + 1 + (top * (fwidth + 2));
	
	for (int y = top; y < fheight; y++)
	{
		unsigned int *ptr = (unsigned *) (baseptr + y * 2 * rowbytes);
		
		for (int x = 0; x < fwidth; x++)
		{
			int v1 = (int) *ptr1;
			int v2 = (int) *(ptr1 + 1);
			int v3 = (int) *(ptr1 + fwidth + 2);
			int v4 = (int) *(ptr1 + fwidth + 2 + 1);
			ptr1++;
			[self setPixel:ptr++ value:(unsigned int) ctab[v1]];
			[self setPixel:ptr value:(unsigned int) ctab[(v1 + v2) >> 1]];
			ptr    = (unsigned int *) (((char *)ptr) + rowbytes - 4);
			[self setPixel:ptr++ value:(unsigned int) ctab[(v1 + v3) >> 1]];
			[self setPixel:ptr value:(unsigned int) ctab[(v1 + v4) >> 1]];
			ptr    = (unsigned int *) (((char *)ptr) - rowbytes + 4);
		}
		// ptr  += rowbytes;
		ptr1 += 2;
	}
}

- (void) FlameActive
{
  int x,v1;
  unsigned char *ptr1;
   
  ptr1 = flame + ((fheight + 1) * (fwidth + 2));

  for (x = 0; x < fwidth + 2; x++)
    {
      v1      = *ptr1;
      v1     += ((random() % variance) - vartrend);
      *ptr1++ = v1;
    }

  if (bloom)
    {
      v1= (random() % 100);
      if (v1 == 10)
		residual += (random()%10);
      else if (v1 == 20)
		hspread += (random()%15);
      else if (v1 == 30)
		vspread += (random()%20);
    }

  residual = ((iresidual* 10) + (residual *90)) / 100;
  hspread  = ((ihspread * 10) + (hspread  *90)) / 100;
  vspread  = ((ivspread * 10) + (vspread  *90)) / 100;
}

- (void) FlameAdvance
{
  int x,y;
  unsigned char *ptr2;
  int newtop = top;

  for (y = fheight + 1; y >= top; y--)
    {
      int used = 0;
      unsigned char *ptr1 = flame + 1 + (y * (fwidth + 2));
      for (x = 0; x < fwidth; x++)
        {
          int v1 = (int)*ptr1;
          int v2, v3;
          if (v1 > 0)
            {
              used = 1;
              ptr2 = ptr1 - fwidth - 2;
              v3   = (v1 * vspread) >> 8;
              v2   = (int)*(ptr2);
              v2  += v3;
              if (v2 > 255) 
                v2 = 255;

              *(ptr2) = (unsigned char)v2;
              v3  = (v1 * hspread) >> 8;
              v2  = (int)*(ptr2 + 1);
              v2 += v3;
              if (v2 > 255) 
                v2 = 255;
          
              *(ptr2 + 1) = (unsigned char)v2;
              v2          = (int)*(ptr2 - 1);
              v2         += v3;
              if (v2 > 255) 
                v2 = 255;
          
              *(ptr2 - 1) = (unsigned char)v2;
        
              if (y < fheight + 1)
                {
                  v1    = (v1 * residual) >> 8;
                  *ptr1 = (unsigned char)v1;
                }
            }
          ptr1++;
          if (used) 
            newtop = y - 1;
        }
 
      /* clean up the right gutter */
      {
        int v1 = (int)*ptr1;
        v1 = (v1 * residual) >> 8;
        *ptr1 = (unsigned char)v1;
      }
    }

  top = newtop - 1;

  if (top < 1)
    top = 1;
}

- (void) FlameFill
{
  int x, y;
  for (y = 0; y < fheight + 1; y++)
    {
      unsigned char *ptr1 = flame + 1 + (y * (fwidth + 2));
      for (x = 0; x < fwidth; x++)
        {
          *ptr1 = 0;
          ptr1++;
        }
    }
}

- (void) FlamePasteData:(unsigned char *) ptr2
{	
	int x, y;
	for (y = 0; y < fheight; y++)
	{
		unsigned char *ptr1 = flame + 1 + (y * (fwidth + 2));
		for (x = 0; x < fwidth; x++)
		{
//			unsigned char val = *ptr2 / 16;
//			
//			*ptr1 += val;
//			if (*ptr2 > 32)
			{
				int v = random () % (*ptr2 * 15 / 255 + 1);
				*ptr1 += v;
			}

			ptr1++;
			ptr2++;
		}
	}
}

- (void) xflame_init
{
	width = [[self context] size].width;
	height = [[self context] size].height;
	
	scratch = [CTUtil CreateBitmapContextPixelsWide:width pixelsHigh:height];

	top      = 1;
	flame    = NULL;

	[self InitColors];

	[self InitFlame];
	[self FlameFill];
}

#define FLAME_MAP_VAL(map,x,y) (map[(y) * width / 2 + (x)])

- (void) scale
{
	int *src = (int *) CGBitmapContextGetData(scratch);
	unsigned int rowbytes = CGBitmapContextGetBytesPerRow(scratch);

	int hscale = 2;
	int vscale = 2;
	
	int *v = src;
	for (int y = 0; y < fheight; y++) 
	{
		int *h = v;
		for (int x = 0; x < fwidth; x++) 
		{
			int *p = h;
			int total = 0;
			for (int yy = 0; yy < hscale; yy ++)
			{
				for (int xx = 0; xx < vscale; xx ++)
				{
					int val = *p++;
					total += getColorComponent(val, FLAME_RED) +
							 getColorComponent(val, FLAME_GREEN) +
							 getColorComponent(val, FLAME_BLUE);
				}
				p -= hscale;
				(char *) p += rowbytes;
			}
			
			FLAME_MAP_VAL(scaled, x, y) = total / hscale / vscale / 3;
			
			h += hscale;
		}
		
		(char *) v += hscale * rowbytes;
	}
}

- (void) sobel
{
	unsigned char * q = sobeled;

	for (int y = 0; y < fheight; y++)  
	{
		for (int x = 0; x < fwidth; x++) 
		{
			int accumH = 0;
			int accumV = 0;
			int SUM = 0;

			/* image boundaries */
			if (y == 0 || y == fheight - 1)
				SUM = 0;
			else if (x == 0 || x == fwidth - 1)
				SUM = 0;
			else   
			{
				unsigned char pixel;
				
				pixel = FLAME_MAP_VAL(scaled, x - 1, y - 1);
				accumV += pixel*kern00;
				accumH += pixel*kern00;
				pixel = FLAME_MAP_VAL(scaled, x, y - 1);
				accumV += pixel*kern01;
				accumH += pixel*kern10;
				pixel = FLAME_MAP_VAL(scaled, x + 1, y - 1);
				accumV += pixel*kern02;
				accumH += pixel*kern20;
				pixel = FLAME_MAP_VAL(scaled, x - 1, y);
				accumV += pixel*kern10;
				accumH += pixel*kern01;
				pixel = FLAME_MAP_VAL(scaled, x, y);
				accumV += pixel*kern11;
				accumH += pixel*kern11;
				pixel = FLAME_MAP_VAL(scaled, x + 1, y);
				accumV += pixel*kern12;
				accumH += pixel*kern21;
				pixel = FLAME_MAP_VAL(scaled, x - 1, y + 1);
				accumV += pixel*kern20;
				accumH += pixel*kern02;
				pixel = FLAME_MAP_VAL(scaled, x, y + 1);
				accumV += pixel*kern21;
				accumH += pixel*kern12;
				pixel = FLAME_MAP_VAL(scaled, x + 1, y + 1);
				accumV += pixel*kern22;
				accumH += pixel*kern22;

				/*---GRADIENT MAGNITUDE APPROXIMATION (Myler p.218)----*/
				SUM = abs(accumV) + abs(accumH);
			}

			if (SUM > 255)
				SUM = 255;
			if (SUM < 0)
				SUM = 0;

			*q++ = SUM;
		}
	}
}

- (void) doit
{
	[self FlameActive];

	unsigned char *ddata = (unsigned char *) CGBitmapContextGetData(scratch);
	unsigned int rowbytes = CGBitmapContextGetBytesPerRow(scratch);
	[[self context] fetchOpenGLPixels:ddata rowBytes:rowbytes];

	[self scale];
	[self sobel];
	
	[self FlamePasteData:sobeled];

	[self FlameAdvance];
	
	[self Flame2Image32];
	
	CGImageRef cgimg = CGBitmapContextCreateImage (scratch);
	CIImage *ciimg = [CIImage imageWithCGImage:cgimg];
	
	[[[self context] ciCtx] drawImage:ciimg atPoint:CGPointZero fromRect:[ciimg extent]];
	
	CGImageRelease(cgimg);	
}

@end
