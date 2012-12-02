#import <Foundation/Foundation.h>
#import "XMPPMessage.h"


@interface XMPPMessage(XEP0045)

@property (nonatomic, strong) NSString *subject;

+(id)groupChatMessageWithSubject:(NSString*)subject to:(XMPPJID*)jid;

- (BOOL)isGroupChatMessage;
- (BOOL)isGroupChatMessageWithBody;
- (XMPPJID*)roomInviteFrom;
- (XMPPJID*)roomInviteJid;

@end
