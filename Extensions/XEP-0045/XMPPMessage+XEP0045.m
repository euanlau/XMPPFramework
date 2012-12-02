#import "XMPPMessage+XEP0045.h"
#import "XMPPRoom.h"
#import "NSXMLElement+XMPP.h"
#import "XMPPJID.h"

@implementation XMPPMessage(XEP0045)

+(id)groupChatMessageWithSubject:(NSString*)subject to:(XMPPJID*)jid
{
  XMPPMessage *message = [XMPPMessage messageWithType:XMPPMessageTypeGroupChat to:jid];
  NSXMLElement *elem = [NSXMLElement elementWithName:@"subject" stringValue:subject];
  [message addChild:elem];
  return message;
}

- (BOOL)isGroupChatMessage
{
	return [[[self attributeForName:@"type"] stringValue] isEqualToString:@"groupchat"];
}

- (BOOL)isGroupChatMessageWithBody
{
	if ([self isGroupChatMessage])
	{
		NSString *body = [[self elementForName:@"body"] stringValue];
		
		return ((body != nil) && ([body length] > 0));
	}
	
	return NO;
}

- (NSString *)subject
{
  NSString *subject = nil;
  if ([self isGroupChatMessage])
  {
    subject = [[self elementForName:@"subject"] stringValue];
  }
  return subject;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void) setSubject:(NSString *)subject
{
  NSXMLElement *subjectElement = [self elementForName:@"subject"];
  if (!subjectElement)
  {
    subjectElement = [NSXMLElement elementWithName:@"subject" stringValue:subject];
    [self addChild:subjectElement];
  }
  else
  {
    [subjectElement setStringValue:subject];
  }
}


- (XMPPJID *)roomInviteFrom
{
  NSXMLElement * x = [self elementForName:@"x" xmlns:XMPPMUCUserNamespace];
	NSXMLElement * invite  = [x elementForName:@"invite"];
	NSXMLElement * directInvite = [self elementForName:@"x" xmlns:@"jabber:x:conference"];
	
  XMPPJID *inviteFrom = nil;
  
	if (invite)
  {
    NSString *from = [invite attributeStringValueForName:@"from"];
    inviteFrom = [XMPPJID jidWithString:from];
  }
  else if (directInvite)
  {
    inviteFrom = [self from];
  }
  
  return inviteFrom;
}

- (XMPPJID*)roomInviteJid
{
	// Examples from XEP-0045:
	// 
	// 
	// Example 124. Room Sends Invitation to New Member:
	// 
	// <message from='darkcave@chat.shakespeare.lit' to='hecate@shakespeare.lit'>
	//   <x xmlns='http://jabber.org/protocol/muc#user'>
	//     <invite from='bard@shakespeare.lit'/>
	//     <password>cauldronburn</password>
	//   </x>
	// </message>
	// 
  // Examples from XEP-0249:
	// 
	// 
	// Example 1. A direct invitation
	// 
	// <message from='crone1@shakespeare.lit/desktop' to='hecate@shakespeare.lit'>
	//   <x xmlns='jabber:x:conference'
	//      jid='darkcave@macbeth.shakespeare.lit'
	//      password='cauldronburn'
	//      reason='Hey Hecate, this is the place for all good witches!'/>
	// </message>
  
  
  NSXMLElement * directInvite = [self elementForName:@"x" xmlns:@"jabber:x:conference"];
  NSXMLElement * x = [self elementForName:@"x" xmlns:XMPPMUCUserNamespace];
	NSXMLElement * invite  = [x elementForName:@"invite"];

  XMPPJID *jid = nil;
  
	if (directInvite)
	{
    NSString *inviteJidStr = [directInvite attributeStringValueForName:@"jid"];
    jid = [XMPPJID jidWithString:inviteJidStr];
  }
  else if (invite)
  {
    jid = [self from];
  }
  
  return  jid;
}



@end
