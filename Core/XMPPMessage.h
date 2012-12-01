#import <Foundation/Foundation.h>
#import "XMPPElement.h"

typedef enum XMPPMessageType {
  XMPPMessageTypeNone,
  XMPPMessageTypeChat,
  XMPPMessageTypeGroupChat,
  XMPPMessageTypeNormal,
  XMPPMessageTypeError,
  XMPPMessageTypeHeadline
} XMPPMessageType;

/**
 * The XMPPMessage class represents a <message> element.
 * It extends XMPPElement, which in turn extends NSXMLElement.
 * All <message> elements that go in and out of the
 * xmpp stream will automatically be converted to XMPPMessage objects.
 * 
 * This class exists to provide developers an easy way to add functionality to message processing.
 * Simply add your own category to XMPPMessage to extend it with your own custom methods.
**/

@interface XMPPMessage : XMPPElement

// Converts an NSXMLElement to an XMPPMessage element in place (no memory allocations or copying)
+ (XMPPMessage *)messageFromElement:(NSXMLElement *)element;

+ (XMPPMessage *)message;
+ (XMPPMessage *)messageWithType:(XMPPMessageType)type;
+ (XMPPMessage *)messageWithType:(XMPPMessageType)type to:(XMPPJID *)to;

- (id)init;
- (id)initWithType:(XMPPMessageType)type;
- (id)initWithType:(XMPPMessageType)type to:(XMPPJID *)to;

- (BOOL)isChatMessage;
- (BOOL)isChatMessageWithBody;
- (BOOL)isErrorMessage;
- (BOOL)isMessageWithBody;

- (NSError *)errorMessage;

@property (nonatomic, assign) XMPPMessageType type;
@property (nonatomic, strong) NSString *body;

@end
