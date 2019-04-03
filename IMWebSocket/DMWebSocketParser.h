//
//  DMWebSocketParser.h
//  IMWebSocket
//
//  Created by jfdreamyang on 2019/3/29.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DMWebSocketParserDelegate <NSObject>
-(void)parserDidConnected;
-(void)parserDidError:(NSError *)error;
-(void)didReceiveMessage:(NSData *)message opCode:(UInt8)opCode;
@end

NS_ASSUME_NONNULL_BEGIN

@interface DMWebSocketParser : NSObject
@property (nonatomic,weak)id <DMWebSocketParserDelegate> delegate;
@property (nonatomic,strong,readonly)NSString *securityKey;
-(void)append:(NSData *)frame;
-(NSData *)createFrame:(NSData *)message opCode:(UInt8)opCode;
-(NSData *)createFrame:(NSData *)message opCode:(UInt8)opCode payloadLength:(NSUInteger)payloadLength;
@end

NS_ASSUME_NONNULL_END
