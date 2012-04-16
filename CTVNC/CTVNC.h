#import <Cocoa/Cocoa.h>
#import "CTEffect.h"

@class VLCClient;

@interface CTVNC : CTEffect 
{	
	NSString	*host;
	int			port;	// Should be unsigned short but bindings likes it this way
	NSString	*username;
	NSString	*password;
	BOOL		autoConnect;
	
	NSViewController *viewController;
	
	VLCClient *client;
}

@end
