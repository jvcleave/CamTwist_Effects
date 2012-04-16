#import <Cocoa/Cocoa.h>
#import "CTEffect.h"

@interface Flame : CTEffect 
{
	int             width;
	int             height;
	bool            shared;
	bool            bloom;
	unsigned        ctab[256];

	unsigned char  *flame;
	unsigned char  *scaled;
	unsigned char  *sobeled;
	int             fwidth;
	int             fheight;
	int             top;
	int             hspread;
	int             vspread;
	int             residual;

	int ihspread;
	int ivspread;
	int iresidual;
	int variance;
	int vartrend;
	
	CGContextRef	scratch;
}

@end
