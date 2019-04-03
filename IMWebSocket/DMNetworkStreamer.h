//
//  DMNetworkStreamer.h
//  IMWebSocket
//
//  Created by jfdreamyang on 2019/3/28.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import <Foundation/Foundation.h>



typedef enum : NSUInteger {
    DMNetworkStreamerStateConnected,
    DMNetworkStreamerStateFailed,
    DMNetworkStreamerStateWaiting,
    DMNetworkStreamerStateCancelled
} DMNetworkStreamerState;


@protocol DMNetworkStreamerDelegate <NSObject>
-(void)streamDidConnect:(DMNetworkStreamerState)state;
-(void)streamDidError:(NSError *)error;
-(void)streamDidReceiveMessage:(NSData *)message;
@end

NS_ASSUME_NONNULL_BEGIN

@interface DMNetworkStreamer : NSObject
- (instancetype)initWithRequest:(NSURLRequest *)request;

-(void)connect;

-(void)cleanup;

/**
 设置接收消息代理
 */
@property (nonatomic,weak)id <DMNetworkStreamerDelegate>delegate;

/**
 发送数据

 @param frame 数据帧
 */
-(void)write:(NSData *)frame;

@end

NS_ASSUME_NONNULL_END
