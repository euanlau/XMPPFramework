//
//  XMPPMessage+Holla.m
//  Justalk
//
//  Created by Yiu Woon Lau on 8/17/12.
//  Copyright (c) 2012, Justalk Inc. All rights reserved.
//

#import "XMPPMessage+MUC.h"
#import "XMPPMessage+XEP0045.h"
#import "XMPPJID.h"
#import "NSXMLElement+XMPP.h"

@implementation XMPPMessage (MUC)

+(id)groupChatInviteNotificationMessageForRoom:(XMPPJID *)roomJID to:(XMPPJID *)toJID
{
  NSXMLElement *invite = [NSXMLElement elementWithName:@"invite"];
  [invite addAttributeWithName:@"to" stringValue:[toJID full]];
  
  XMPPMessage *message = [XMPPMessage messageWithType:XMPPMessageTypeGroupChat to:roomJID];
  [message addChild:invite];
  return message;
}

- (XMPPJID *)roomInviteTo
{
  XMPPJID *jid = nil;
  if ([self isGroupChatMessage])
  {
    NSXMLElement *invite = [self elementForName:@"invite"];
    NSString *toStr = [invite attributeStringValueForName:@"to"];
    jid = [XMPPJID jidWithString:toStr];
  }
  return jid;
}

- (XMPPJID *)roomExitFrom
{
  XMPPJID *jid = nil;
  if ([self isGroupChatMessage])
  {
    NSXMLElement *exit = [self elementForName:@"exit"];
    NSString *fromStr = [exit attributeStringValueForName:@"from"];
    jid = [XMPPJID jidWithString:fromStr];
  }
  return jid;
}

+ (id)exitGroupChatMessageForRoom:(XMPPJID *)roomJID from:(XMPPJID *)from
{
  XMPPMessage *message = [XMPPMessage messageWithType:XMPPMessageTypeGroupChat to:roomJID];

  NSXMLElement *exit = [NSXMLElement elementWithName:@"exit"];
  [exit addAttributeWithName:@"from" stringValue:[from bare]];

  [message addChild:exit];
  return  message;
}

+ (id)inviteGroupChatMessageForRoom:(XMPPJID *)roomJID to:(XMPPJID *)to
{
  NSXMLElement *invite = [NSXMLElement elementWithName:@"invite"];
  [invite addAttributeWithName:@"to" stringValue:[to full]];
  
  XMPPMessage *message = [XMPPMessage messageWithType:XMPPMessageTypeGroupChat to:roomJID];
  [message addChild:invite];
  return message;
}
@end
