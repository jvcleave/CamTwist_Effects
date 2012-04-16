#import "CTVNC.h"
#import "CTUtil.h"

#include <rfb/rfbclient.h>

@class CTEffectProxy;

///////////////////////////////////////////////////////////////////////////////////

@interface VLCClient : NSObject
{
	rfbClient *cl;
	BOOL bKeepGoing;
	
	NSOpenGLContext *oglctx;
	CVOpenGLBufferRef backingBuffer;
	
	u_short port;
	NSString *host;
	NSString *username;
	NSString *password;
}

- (BOOL) isConnected;

// Private
- (BOOL) resize;
- (rfbCredential *) getCredentials:(int) type;
- (char *) getPassword;
- (void) updateX:(int) x
			   Y:(int) y
			   W:(int) w
			   H:(int) h;

@end

///////////////////////////////////////////////////////////////////////////////////

static int someVar;

static rfbBool resize(rfbClient* client) 
{
	VLCClient *g = (VLCClient *) rfbClientGetClientData(client, &someVar);
	return [g resize];
}

static void update(rfbClient* client,int x,int y,int w,int h) 
{
	VLCClient *g = (VLCClient *) rfbClientGetClientData(client, &someVar);
	[g updateX:x Y:y W:w H:h];
}

static rfbCredential * getcred(rfbClient* client, int type)
{
	VLCClient *g = (VLCClient *) rfbClientGetClientData(client, &someVar);
	return [g getCredentials:type];
}

static char * getpass(rfbClient* client)
{
	VLCClient *g = (VLCClient *) rfbClientGetClientData(client, &someVar);
	return [g getPassword];
}

///////////////////////////////////////////////////////////////////////////////////

@implementation VLCClient

- (void) dealloc
{
	NSLog(@"client dealloc");
	
	CVOpenGLBufferRelease(backingBuffer);
	
	[host release];
	[username release];
	[password release];
	[oglctx release];
	
	[super dealloc];
}

- (void) _fireConnectedKVO
{
	[self willChangeValueForKey:@"connected"];
	[self didChangeValueForKey:@"connected"];
}

- (void) connectTo:(NSString *) theHost
			onPort:(u_short) thePort
	  withUserName:(NSString *) user
	   andPassword:(NSString *) pass
{
	[username release];
	[password release];
	
	host = [theHost retain];
	port = thePort;
	username = [user retain];
	password = [pass retain];
		
	bKeepGoing = YES;
	
	[NSThread detachNewThreadSelector:@selector(worker) toTarget:self withObject:nil];
}	

- (void) disconnect
{
	@synchronized(self) {
		bKeepGoing = NO;
	}
}

- (BOOL) isConnected
{
	@synchronized(self) {
		return cl != nil;
	}
}

- (BOOL) resize
{
	//NSLog(@"resize");
	
	int width = cl->width;
	int height = cl->height;
	int	depth = cl->format.bitsPerPixel;
	
	//NSLog(@"%w:%d h:%d d:%d", width, height, depth);
	
	if (cl->frameBuffer)
		free(cl->frameBuffer);
	
	cl->frameBuffer = (uint8_t *) malloc(width * height * depth / 8);
	
	NSOpenGLPixelFormatAttribute attributes[] = 
	{
		NSOpenGLPFAPixelBuffer,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFADepthSize, (NSOpenGLPixelFormatAttribute) 24,
		(NSOpenGLPixelFormatAttribute) 0
	};
	
	NSOpenGLPixelFormat *fmt = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];

	@synchronized(self) {
		[oglctx release];
		CVOpenGLBufferRelease(backingBuffer);

		oglctx = [[NSOpenGLContext alloc] initWithFormat:fmt shareContext:[[CamTwist instance] sharedGLContext]];
		
		CGLContextObj cgl_ctx = (CGLContextObj) [self->oglctx CGLContextObj];
		CGLSetCurrentContext(cgl_ctx);
			
		glViewport (0, 0, width, height);	
		glMatrixMode (GL_PROJECTION);
		glLoadIdentity ();
		glOrtho (0, width, 0, height, -1, 1);
		glMatrixMode (GL_MODELVIEW);
		glLoadIdentity ();
		
		CVOpenGLBufferCreate (nil, width, height, nil, &backingBuffer);
		CVOpenGLBufferAttach (backingBuffer, cgl_ctx, 0, 0, 0);
		
		[CTContext clearContext:oglctx toRed:0 green:0 blue:0 alpha:1];
	}
		
	[fmt release];
	
	return true;
}

- (rfbCredential *) getCredentials:(int) type
{
	// NSLog(@"Looking for cred type %d", type);
	
	if (type == rfbCredentialTypeUser)
	{
		rfbCredential *cred = (rfbCredential *) malloc(sizeof(rfbCredential));
		cred->userCredential.username = strdup(username ? [username UTF8String] : "");
		cred->userCredential.password = strdup(password ? [password UTF8String] : "");
		return cred;
	}
	
	return nil;
}

- (char *) getPassword
{
	return strdup(password ? [password UTF8String] : "");
}

- (void) updateX:(int) x
			   Y:(int) y
			   W:(int) w
			   H:(int) h
{
#if 0
	x = y = 0;
	w = cl->width;
	h = cl->height;
#endif
	
	// NSLog(@"update %d %d %d %d", x, y, w, h);
	
	int width = cl->width;
	int height = cl->height;

	CGLContextObj cgl_ctx = (CGLContextObj) [self->oglctx CGLContextObj];
	CGLSetCurrentContext(cgl_ctx);

	////
	
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glPixelStorei(GL_UNPACK_SWAP_BYTES, 0);
	glPixelStorei(GL_UNPACK_LSB_FIRST, 0);
	glPixelStorei(GL_UNPACK_ROW_LENGTH, width);		// This is the row stride, I think.
	glPixelStorei(GL_UNPACK_IMAGE_HEIGHT, 0);		// This is determined some other way?
	glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
	glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);
	
	GLuint texture;
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_RECTANGLE_ARB, texture);

	// Where is the first pixel in the framebuffer
	unsigned char *pix = cl->frameBuffer;
	
	// Advance to the first update row
	pix += y * width * 4;
	
	// Advance to the first pixel in the row
	pix += x * 4;
	
	// Create a texure with just the updated area
	glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGB, w, h,
				 0, GL_RGBA, GL_UNSIGNED_BYTE, pix);
	
	// Draw it into our scene
	CGRect frect = CGRectMake(0, 0, w, h);
	CGRect trect = CGRectMake(x, y, w, h);

	[CTContext drawTexture:texture 
				  fromRect:frect 
				 toContext:oglctx
					inRect:trect 
				   flipped:YES 
				  mirrored:NO];
	
	glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);
	glDeleteTextures(1, &texture);
}

- (void) worker
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	@synchronized(self) {
		cl = rfbGetClient(8,3,4);
	}
		
	rfbClientSetClientData(cl, &someVar, self);
	
	cl->MallocFrameBuffer = resize;
	cl->canHandleNewFBSize = TRUE;
	cl->GotFrameBufferUpdate = update;
	//cl->HandleKeyboardLedState=kbd_leds;
	//cl->HandleTextChat=text_chat;
	//cl->GotXCutText = got_selection;
	//cl->listenPort = LISTEN_PORT_OFFSET;
	cl->serverPort = port;
	cl->serverHost = strdup([host UTF8String]);
	cl->GetCredential = getcred;
	cl->GetPassword = getpass;
	
	// If we have a username, use ARD else use VNC
	uint32 authSchemes = [username length] ? rfbARD : rfbVncAuth;
	SetClientAuthSchemes(cl, &authSchemes, 1);
	
	if (!rfbInitClient(cl, nil, nil))
	{
		cl = nil; // rfbInitClient has already freed the client struct
		bKeepGoing = NO;
	}
	
	// NSLog(@"Connected");
	
	for (;;)
	{
		@synchronized(self) {
			if (!bKeepGoing)
				break;
		}
		
		int i = WaitForMessage(cl, 2000000);

		if (i < 0)
			break;
		
		if (i > 0 && !HandleRFBServerMessage(cl))
			break;
	}
	
	@synchronized(self) {
		if (cl)
			rfbClientCleanup(cl);
		cl = nil;
	}
	
	[self performSelectorOnMainThread:@selector(_fireConnectedKVO) withObject:nil waitUntilDone:NO];

	NSLog(@"worker exit");

	[pool release];
}

- (void) doitToContext:(NSOpenGLContext *)otherContext
{
	@synchronized(self)
	{
		[CTContext drawPBuffer:backingBuffer toContext:otherContext flipped:NO mirrored:NO];
	}
}

@end

///////////////////////////////////////////////////////////////////////////////////

@implementation CTVNC

+ (NSString *) name
{
	return @"VNC";
}

+ (BOOL) isSource
{
	return YES;
}

- (void) initCommon
{	
	viewController = [[NSViewController alloc] initWithNibName:@"CTVNC" 
														bundle:[NSBundle bundleForClass:[CTVNC class]]];
	[viewController setRepresentedObject:self];
}

- (id) initWithContext:(CTContext *) ctContext
{
	self = [super initWithContext:ctContext]; 
	
	host = @"";
	port = 5900;
	username = @"";
	password = @"";
	autoConnect = NO;
	
	[self initCommon];
		
	return [[CTEffectProxy proxyWithRealMcCoy:self] retain];
}

- (id) initWithCoder:(NSCoder *) coder
{
	self = [super initWithCoder:coder];
	
	host = [[coder decodeObjectForKey:@"host"] retain];
	port = [coder decodeIntForKey:@"port"];
	password = [[coder decodeObjectForKey:@"password"] retain];
	username = [[coder decodeObjectForKey:@"username"] retain];
	autoConnect = [coder decodeBoolForKey:@"autoConnect"];
	
	[self initCommon];
	
	if (autoConnect)
		[self setConnected:YES];

	return [[CTEffectProxy proxyWithRealMcCoy:self] retain];
}

- (void) destruct
{
	[viewController setRepresentedObject:nil];
}

- (NSView *) inspectorView
{
	return [viewController view];
}

- (void) encodeWithCoder:(NSCoder *) coder
{
	[super encodeWithCoder:coder];
	
	[coder encodeObject:host forKey:@"host"];
	[coder encodeInt:port forKey:@"port"];
	[coder encodeObject:password forKey:@"password"];
	[coder encodeObject:username forKey:@"username"];
	[coder encodeBool:autoConnect forKey:@"autoConnect"];
}

- (void) dealloc
{
//	NSLog(@"ctvnc dealloc");
	
	[host release];
	[username release];
	[password release];

	[viewController release];
	[client disconnect];
	[client release];

	[super dealloc];
}

- (void) setConnected:(BOOL) b
{
	// Aways start fresh
	[client disconnect];
	client = nil;

	if (b)
	{
		client = [[VLCClient alloc] init];
		[client connectTo:host onPort:port withUserName:username andPassword:password];
	}
}

- (BOOL) isConnected
{
	client && [client isConnected];
}

- (void) doit
{
	[client doitToContext:[[self context] oglCtx]];
}

@end
