#import <Foundation/Foundation.h>
#import "XMPP.h"
#import "XMPPRoom.h"

@protocol XMPPMUCStorage;

#define _XMPP_MUC_H

typedef enum _XMPPMUCErrorType {
  XMPPMUCExceedMaximumRoomCountErrorType = 0
} XMPPMUCErrorType;

/**
 * The XMPPMUC module, combined with XMPPRoom and associated storage classes,
 * provides an implementation of XEP-0045 Multi-User Chat.
 * 
 * The bulk of the code resides in XMPPRoom, which handles the xmpp technical details
 * such as surrounding joining/leaving a room, sending/receiving messages, etc.
 * 
 * The XMPPMUC class provides general (but important) tasks relating to MUC:
 *  - It integrates with XMPPCapabilities (if available) to properly advertise support for MUC.
 *  - It monitors active XMPPRoom instances on the xmppStream,
 *    and provides an efficient query to see if a presence or message element is targeted at a room.
 *  - It listens for MUC room invitations sent from other users.
**/

@interface XMPPMUC : XMPPModule <XMPPStreamDelegate>
{
/*	Inherited from XMPPModule:
	 
	XMPPStream *xmppStream;
	
	dispatch_queue_t moduleQueue;
 */
  
  __strong id <XMPPMUCStorage> xmppMUCStorage;
	NSMutableSet *rooms;  
}

- (id)initWithMUCStorage:(id<XMPPMUCStorage>)storage;
- (id)initWithMUCStorage:(id<XMPPMUCStorage>)storage dispatchQueue:(dispatch_queue_t)queue;

/* Inherited from XMPPModule:
 
- (id)init;
- (id)initWithDispatchQueue:(dispatch_queue_t)queue;

- (BOOL)activate:(XMPPStream *)xmppStream;
- (void)deactivate;

@property (readonly) XMPPStream *xmppStream;
 
- (NSString *)moduleName;
 
*/

@property (nonatomic, assign, getter = isAutoAcceptInvitation) BOOL autoAcceptInvitation;
@property (atomic, assign) NSUInteger maxRoomCount;

- (BOOL)isMUCRoomPresence:(XMPPPresence *)presence;
- (BOOL)isMUCRoomMessage:(XMPPMessage *)message;
- (void)createRoomWithParticipants:(NSArray *)participants subject:(NSString*)subject;
- (XMPPRoom *)roomWithJID:(XMPPJID *)jid;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPMUCDelegate
@optional

- (void)xmppMUC:(XMPPMUC *)sender didReceiveRoomInvitation:(XMPPMessage *)message;
- (void)xmppMUC:(XMPPMUC *)sender didReceiveRoomInvitationDecline:(XMPPMessage *)message;
- (void)xmppMUC:(XMPPMUC *)sender didReceiveMessage:(XMPPMessage *)message;
- (void)xmppMUC:(XMPPMUC *)sender didReceivePresence:(XMPPPresence *)presence;
- (void)xmppMUC:(XMPPMUC *)sender didReceiveIQ:(XMPPIQ *)iq;

- (void)xmppMUC:(XMPPMUC *)sender didCreateRoom:(XMPPRoom *)room;
- (void)xmppMUC:(XMPPMUC *)sender didFailToCreateRoomWithError:(NSError *)error;
@end

@protocol XMPPMUCStorage <XMPPRoomStorage>
- (NSDictionary *)fetchExistingRoomJids:(XMPPMUC *)sender;
@optional

- (void)xmppMUC:(XMPPMUC *)sender handleInvitation:(XMPPMessage *)message;
@end
