#import <Foundation/Foundation.h>
#import <libxml/HTMLparser.h>

#import "SAXErrorHandler.h"

void errorHandler(void *context, const char *msg, ...) {
	id<SAXErrorHandler> delegate = (__bridge id<SAXErrorHandler>)context;
	
	char string[256];
	va_list arg_ptr;
	
	va_start(arg_ptr, msg);
	vsnprintf(string, 256, msg, arg_ptr);
	va_end(arg_ptr);
	
	NSString *errorMsg = [NSString stringWithUTF8String:string];
	
	[delegate parseErrorOccurred:errorMsg];
}

void useErrorHandlerProtocol(htmlSAXHandler * _Nonnull handler) {
	(*handler).error = errorHandler;
}
