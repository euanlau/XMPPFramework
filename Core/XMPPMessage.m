#import "XMPPMessage.h"
#import "XMPPJID.h"
#import "NSXMLElement+XMPP.h"

#import <objc/runtime.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif


@implementation XMPPMessage

+ (void)initialize
{
	// We use the object_setClass method below to dynamically change the class from a standard NSXMLElement.
	// The size of the two classes is expected to be the same.
	// 
	// If a developer adds instance methods to this class, bad things happen at runtime that are very hard to debug.
	// This check is here to aid future developers who may make this mistake.
	// 
	// For Fearless And Experienced Objective-C Developers:
	// It may be possible to support adding instance variables to this class if you seriously need it.
	// To do so, try realloc'ing self after altering the class, and then initialize your variables.
	
	size_t superSize = class_getInstanceSize([NSXMLElement class]);
	size_t ourSize   = class_getInstanceSize([XMPPMessage class]);
	
	if (superSize != ourSize)
	{
		NSLog(@"Adding instance variables to XMPPMessage is not currently supported!");
		exit(15);
	}
}

+ (XMPPMessage *)messageFromElement:(NSXMLElement *)element
{
	object_setClass(element, [XMPPMessage class]);
	
	return (XMPPMessage *)element;
}

+ (XMPPMessage *)message
{
	return [[XMPPMessage alloc] init];
}

+ (XMPPMessage *)messageWithType:(XMPPMessageType)type
{
	return [[XMPPMessage alloc] initWithType:type to:nil];
}

+ (XMPPMessage *)messageWithType:(XMPPMessageType)type to:(XMPPJID *)to
{
	return [[XMPPMessage alloc] initWithType:type to:to];
}

- (id)init
{
	self = [super initWithName:@"message"];
	return self;
}

- (id)initWithType:(XMPPMessageType)type
{
	return [self initWithType:type to:nil];
}

- (id)initWithType:(XMPPMessageType)type to:(XMPPJID *)to
{
	if ((self = [super initWithName:@"message"]))
	{
		self.type = type;
    
		if (to)
			[self addAttributeWithName:@"to" stringValue:[to description]];
	}
	return self;
}

- (BOOL)isChatMessage
{
	return [[[self attributeForName:@"type"] stringValue] isEqualToString:@"chat"];
}

- (BOOL)isChatMessageWithBody
{
	if([self isChatMessage])
	{
		return [self isMessageWithBody];
	}
	
	return NO;
}

- (BOOL)isErrorMessage {
    return [[[self attributeForName:@"type"] stringValue] isEqualToString:@"error"];
}

- (NSError *)errorMessage {
    if (![self isErrorMessage]) {
        return nil;
    }
    
    NSXMLElement *error = [self elementForName:@"error"];
    return [NSError errorWithDomain:@"urn:ietf:params:xml:ns:xmpp-stanzas" 
                               code:[error attributeIntValueForName:@"code"] 
                           userInfo:[NSDictionary dictionaryWithObject:[error compactXMLString] forKey:NSLocalizedDescriptionKey]];

}

- (BOOL)isMessageWithBody
{
	return ([self elementForName:@"body"] != nil);
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (XMPPMessageType) type
{
  NSString *typeStr = [[self attributeStringValueForName:@"type"] lowercaseString];
  
  if (!typeStr)
    return XMPPMessageTypeNone;
  
  if ([typeStr isEqualToString:@"chat"])
    return XMPPMessageTypeChat;
  
  if ([typeStr isEqualToString:@"groupchat"])
    return XMPPMessageTypeGroupChat;
  
  if ([typeStr isEqualToString:@"error"])
    return XMPPMessageTypeError;
  
  if ([typeStr isEqualToString:@"headline"])
    return XMPPMessageTypeHeadline;
  
  if ([typeStr isEqualToString:@"normal"])
    return XMPPMessageTypeNormal;
  
  return XMPPMessageTypeNone;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void) setType:(XMPPMessageType)type
{
  NSXMLNode *typeAttribute = [self attributeForName:@"type"];
  
  NSString *typeStr;
  
  switch (type) {
    case XMPPMessageTypeChat:
      typeStr = @"chat";
      break;
    case XMPPMessageTypeGroupChat:
      typeStr = @"groupchat";
      break;
    case XMPPMessageTypeError:
      typeStr = @"error";
      break;
    case XMPPMessageTypeHeadline:
      typeStr = @"headline";
      break;
    case XMPPMessageTypeNormal:
      typeStr = @"normal";
      break;
      
    case XMPPMessageTypeNone:
    default:
      if (typeAttribute)
        [self removeAttributeForName:@"type"];
      return;
  }
  
  if (!typeAttribute)
  {
    [self addAttributeWithName:@"type" stringValue:typeStr];
  }
  else
  {
    [typeAttribute setStringValue:typeStr];
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *) body
{
  return [[self elementForName:@"body"] stringValue];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void) setBody:(NSString *)body
{
  NSXMLElement *bodyElement = [self elementForName:@"body"];
  if (!bodyElement)
  {
    bodyElement = [NSXMLElement elementWithName:@"body" stringValue:body];
    [self addChild:bodyElement];
  }
  else
  {
    [bodyElement setStringValue:body];
  }
}

@end
