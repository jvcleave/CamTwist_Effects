
 
#import "CTEffect.h"

typedef int RGB32;



#define CHARNUM 80
#define FONT_W 4
#define FONT_H 4
#define FONT_DEPTH 4

@interface EmptyEffect : CTEffect 
{
  @public
	int videoWidth;
	int videoHeight;
	int rowwords;
	int video_area;

	int stat;
	int mode;
	unsigned char *scaled;
	unsigned char *img;
	int mapW, mapH;
	RGB32 palette[256 * FONT_DEPTH];


	
	CGContextRef scratch;
}

@end
