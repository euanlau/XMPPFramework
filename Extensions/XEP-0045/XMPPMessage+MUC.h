//
//  XMPPMessage+Holla.h
//  Justalk
//
//  Created by Yiu Woon Lau on 8/17/12.
//  Copyright (c) 2012, Justalk Inc. All rights reserved.
//

#import "XMPPMessage.h"

@interface XMPPMessage (MUC)

- (XMPPJID*)roomInviteTo;
- (XMPPJID*)roomExitFrom;

+ (id)exitGroupChatMessageForRoom:(XMPPJID *)roomJID from:(XMPPJID *)from;
+ (id)inviteGroupChatMessageForRoom:(XMPPJID *)roomJID to:(XMPPJID *)to;

@end
