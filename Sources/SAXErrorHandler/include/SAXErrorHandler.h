#import <Foundation/Foundation.h>
#import <libxml/HTMLparser.h>

void useErrorHandlerProtocol(htmlSAXHandler * _Nonnull handler);

NS_ASSUME_NONNULL_BEGIN

@protocol SAXErrorHandler
- (void)parseErrorOccurred:(NSString *)message;
@end

NS_ASSUME_NONNULL_END
