#import "XMPP.h"
#import "XMPPMUC.h"
#import "XMPPFramework.h"
#import "XMPPMessage+XEP0045.h"
#import "XMPPLogging.h"

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@interface XMPPMUC ()
- (XMPPRoom *)createRoom:(XMPPJID *)jid withSubject:(NSString *)subject;
@end


@implementation XMPPMUC

@synthesize autoAcceptInvitation = _autoAcceptInvitation;

- (id)init 
{
  return [self initWithMUCStorage:nil dispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	return [self initWithMUCStorage:nil dispatchQueue:queue];
}

- (id)initWithMUCStorage:(id<XMPPMUCStorage>)storage
{
  return [self initWithMUCStorage:storage dispatchQueue:NULL];
}

- (id)initWithMUCStorage:(id<XMPPMUCStorage>)storage dispatchQueue:(dispatch_queue_t)queue
{
  if ((self = [super initWithDispatchQueue:queue]))
  {
    if ([storage configureWithParent:self queue:moduleQueue])
		{
			xmppMUCStorage = storage;
		}
		else
		{
			XMPPLogError(@"%@: %@ - Unable to configure storage!", THIS_FILE, THIS_METHOD);
		}

    rooms = [[NSMutableSet alloc] init];
    self.maxRoomCount = 10;
  }
  return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
#ifdef _XMPP_CAPABILITIES_H
		[xmppStream autoAddDelegate:self delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
#endif
    
    NSDictionary *jids = [xmppMUCStorage fetchExistingRoomJids:self];
    
    [jids enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
      
      NSString *subject = [obj isKindOfClass:[NSNull class]] ? nil : obj;
      
      [self createRoom:key withSubject:subject];
    }];
    
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
#ifdef _XMPP_CAPABILITIES_H
	[xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
#endif
  
  for (XMPPRoom *room in rooms)
  {
    [self removeDelegate:room];
    [room removeDelegate:self];
    [room deactivate];
  }
  
  [rooms removeAllObjects];
	
	[super deactivate];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma Private
///////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)generateRoomName
{
  NSAssert(dispatch_get_current_queue() == moduleQueue, @"Private method: MUST run on moduleQueue");
  
  NSDateFormatter *formatter= [[NSDateFormatter alloc] init];
  [formatter setDateFormat:@"yyyyMMddHHmmss"];
  [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
  NSString *timestamp = [formatter stringFromDate:[NSDate date]];
  
  return [NSString stringWithFormat:@"%@-%@-%@",
          [[xmppStream myJID] user],
          timestamp,
          [[XMPPStream generateUUID] substringFromIndex:24]];
  
}

- (NSString *)mucDomain
{
  NSString *domain = [[xmppStream myJID] domain];
  if (!domain)
    return nil;
  
  NSString *prefix = @"conference.";
  return [prefix stringByAppendingString:domain];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma Setters Getters
///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setAutoAcceptInvitation:(BOOL)autoAcceptInvitation
{
  dispatch_block_t block = ^{
    _autoAcceptInvitation = autoAcceptInvitation;
  };
  
	if (dispatch_get_current_queue() == moduleQueue)
    block();
  else
    dispatch_sync(moduleQueue, block);  
}

- (BOOL)autoAcceptInvitation
{
  __block BOOL result = 0;
  
  dispatch_block_t block = ^{
    result = _autoAcceptInvitation;
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;  
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)isMUCRoomElement:(XMPPElement *)element
{
	XMPPJID *bareFrom = [[element from] bareJID];
	if (bareFrom == nil)
	{
		return NO;
	}
	
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{ @autoreleasepool {
    [rooms enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
      XMPPRoom *room = obj;
      result = [room.roomJID isEqualToJID:bareFrom options:XMPPJIDCompareBare];
      if (result)
        *stop = YES;
    }];
		
	}};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (BOOL)isMUCRoomPresence:(XMPPPresence *)presence
{
	return [self isMUCRoomElement:presence];
}

- (BOOL)isMUCRoomMessage:(XMPPMessage *)message
{
	return [self isMUCRoomElement:message];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)createRoomWithParticipants:(NSArray *)participants subject:(NSString*)subject
{
  dispatch_block_t block = ^{ @autoreleasepool {
    
    if (rooms.count < self.maxRoomCount)
    {
    
      NSString *roomName = [self generateRoomName];
    
      XMPPJID  *jid  = [XMPPJID jidWithUser:roomName domain:[self mucDomain] resource:nil];
    
      XMPPRoom *room = [self createRoom:jid withSubject:subject];
    
      [multicastDelegate xmppMUC:self didCreateRoom:room];
      
      [room createRoomUsingNickname:[[xmppStream myJID] user] history:nil participants:participants subject:subject];
    }
    else
    {
      NSError *error = [NSError errorWithDomain:@"XMPPMUCErrorDomain"
                                           code:XMPPMUCExceedMaximumRoomCountErrorType
                                       userInfo:nil];
      [multicastDelegate xmppMUC:self didFailToCreateRoomWithError:error];
    }
  }};
    
  if (dispatch_get_current_queue() == moduleQueue)
    block();
  else
    dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (XMPPRoom *)createRoom:(XMPPJID *)jid withSubject:(NSString *)subject
{
  XMPPRoom *room = [[XMPPRoom alloc] initWithRoomStorage:xmppMUCStorage jid:jid];
  room.autoRejoin = YES;
  [room addDelegate:self delegateQueue:moduleQueue];
  [self addDelegate:room delegateQueue:room.moduleQueue];
  [room activate:xmppStream];

  [rooms addObject:room];

	return room;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (XMPPRoom *)roomWithJID:(XMPPJID *)jid
{
  __block XMPPRoom *result = nil;
	
	dispatch_block_t block = ^{ @autoreleasepool {
    
    for (XMPPRoom *room in rooms)
    {
      if ([room.roomJID isEqualToJID:jid options:XMPPJIDCompareBare])
      {
        result = room;
        break;
      }
    }
  }};

	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender didRegisterModule:(id)module
{
	if ([module isKindOfClass:[XMPPRoom class]])
	{
    XMPPRoom *room = (XMPPRoom *)module;
		[rooms addObject:room];
	}
}

- (void)xmppStream:(XMPPStream *)sender willUnregisterModule:(id)module
{
	if ([module isKindOfClass:[XMPPRoom class]])
	{
    XMPPRoom *room = (XMPPRoom *)module;
		[rooms removeObject:room];
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
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
	// 
	// Example 125. Service Returns Error on Attempt by Mere Member to Invite Others to a Members-Only Room
	// 
	// <message from='darkcave@chat.shakespeare.lit' to='hag66@shakespeare.lit/pda' type='error'>
	//   <x xmlns='http://jabber.org/protocol/muc#user'>
	//     <invite to='hecate@shakespeare.lit'>
	//       <reason>
	//         Hey Hecate, this is the place for all good witches!
	//       </reason>
	//     </invite>
	//   </x>
	//   <error type='auth'>
	//     <forbidden xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
	//   </error>
	// </message>
	// 
	// 
	// Example 50. Room Informs Invitor that Invitation Was Declined
	// 
	// <message from='darkcave@chat.shakespeare.lit' to='crone1@shakespeare.lit/desktop'>
	//   <x xmlns='http://jabber.org/protocol/muc#user'>
	//     <decline from='hecate@shakespeare.lit'>
	//       <reason>
	//         Sorry, I'm too busy right now.
	//       </reason>
	//     </decline>
	//   </x>
	// </message>
	// 
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
	
	NSXMLElement * x = [message elementForName:@"x" xmlns:XMPPMUCUserNamespace];
	NSXMLElement * invite  = [x elementForName:@"invite"];
	NSXMLElement * decline = [x elementForName:@"decline"];

	NSXMLElement * directInvite = [message elementForName:@"x" xmlns:@"jabber:x:conference"];
	
	if (invite || directInvite)
	{
    if ([xmppMUCStorage respondsToSelector:@selector(xmppMUC:handleInvitation:)])
    {
      [xmppMUCStorage xmppMUC:self handleInvitation:message];
    }
      
    XMPPJID *roomJID = [message roomInviteJid];
    
    if (roomJID)
    {
      XMPPRoom *room = [self createRoom:roomJID withSubject:nil];
      [room joinRoomUsingNickname:[[xmppStream myJID] user] history:nil];
    }
		[multicastDelegate xmppMUC:self didReceiveRoomInvitation:message];
	}
	else if (decline)
	{
		[multicastDelegate xmppMUC:self didReceiveRoomInvitationDecline:message];
	}
  else
  {
    [multicastDelegate xmppMUC:self didReceiveMessage:message];
  }
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
  [multicastDelegate xmppMUC:self didReceivePresence:presence];
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
  [multicastDelegate xmppMUC:self didReceiveIQ:iq];
  return NO;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark xmppRoom delegate
///////////////////////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)xmppRoomDidJoin:(XMPPRoom *)sender
{
  [sender fetchMembersList:XMPPRoomAffiliationOwner];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)xmppRoomDidLeavePermanently:(XMPPRoom *)sender
{
  [self removeDelegate:sender];
  [sender removeDelegate:self];
  [sender deactivate];
  [rooms removeObject:sender];
}

#ifdef _XMPP_CAPABILITIES_H
/**
 * If an XMPPCapabilites instance is used we want to advertise our support for MUC.
**/
- (void)xmppCapabilities:(XMPPCapabilities *)sender collectingMyCapabilities:(NSXMLElement *)query
{
	// This method is invoked on our moduleQueue.
	
	// <query xmlns="http://jabber.org/protocol/disco#info">
	//   ...
	//   <feature var='http://jabber.org/protocol/muc'/>
	//   ...
	// </query>
	
	NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"];
	[feature addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/muc"];
	
	[query addChild:feature];
}
#endif

@end
