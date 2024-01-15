//
//  DMWebSocket.h
//  IMWebSocket
//
//  Created by jfdreamyang on 2019/3/28.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : UInt8 {
    DMWebSocketOpCodeContinueFrame = 0x00,
    DMWebSocketOpCodeText = 0x01,
    DMWebSocketOpCodeBinary = 0x02,
    // 3-7 are reserved.
    DMWebSocketOpCodeClose = 0x08,
    DMWebSocketOpCodePing = 0x09,
    DMWebSocketOpCodePong = 0x0A
    // B-F reserved.
} DMWebSocketOpCode;


typedef enum DMStatusCode : NSInteger {
    // 0–999: Reserved and not used.
    DMStatusCodeNormal = 1000,
    DMStatusCodeGoingAway = 1001,
    DMStatusCodeProtocolError = 1002,
    DMStatusCodeUnhandledType = 1003,
    // 1004 reserved.
    SRStatusNoStatusReceived = 1005,
    DMStatusCodeAbnormal = 1006,
    DMStatusCodeInvalidUTF8 = 1007,
    DMStatusCodePolicyViolated = 1008,
    DMStatusCodeMessageTooBig = 1009,
    DMStatusCodeMissingExtension = 1010,
    DMStatusCodeInternalError = 1011,
    DMStatusCodeServiceRestart = 1012,
    DMStatusCodeTryAgainLater = 1013,
    // 1014: Reserved for future use by the WebSocket standard.
    DMStatusCodeTLSHandshake = 1015,
    // 1016–1999: Reserved for future use by the WebSocket standard.
    // 2000–2999: Reserved for use by WebSocket extensions.
    // 3000–3999: Available for use by libraries and frameworks. May not be used by applications. Available for registration at the IANA via first-come, first-serve.
    // 4000–4999: Available for use by applications.
} DMStatusCode;


@class DMWebSocket;


NS_ASSUME_NONNULL_BEGIN

@protocol DMWebSocketDelegate <NSObject>
- (void)webSocketDidConnected:(DMWebSocket *)webSocket;
- (void)webSocket:(DMWebSocket *)webSocket pong:(NSData *)pong;
- (void)webSocket:(DMWebSocket *)webSocket ping:(NSData *)ping;
- (void)webSocket:(DMWebSocket *)webSocket didReceiveMessage:(NSData *)message opCode:(DMWebSocketOpCode)opCode;
@optional
- (void)websocketDidDisconnect:(DMWebSocket *)webSocket;
@end


@interface DMWebSocket : NSObject
@property (nonatomic,weak)id <DMWebSocketDelegate>delegate;
/**
 创建 websockt 连接

 @param request 请求
 @param protocols 支持的协议
 @return WebSocket 实例
 */
- (instancetype)initURLRequest:(NSURLRequest *)request protocols:(nullable NSArray <NSString *> *)protocols;
/**
 连接 IM Server
 */
- (void)connect;

/**
 发送消息，如果发送数据过长，会以 continueFrame 的模式去发送，最后服务端会进行组装

 @param message 消息
 @return 发送成功提交
 */
-(BOOL)sendMessage:(NSData *)message;

/**
 发送指定 opcode 消息

 @param message 消息
 @param opCode opCode
 @return 发送成功提交
 */
-(BOOL)sendMessage:(NSData *)message opCode:(DMWebSocketOpCode)opCode;

/**
 发送一条 ping 消息

 @param frame ping 消息内容
 @return 发送成功提交
 */
-(BOOL)ping:(NSData *)frame;

/**
 断开连接
 */
-(void)close;

/**
 断开连接
 */
-(void)close:(NSInteger)waitTimeout closeCode:(DMStatusCode)closeCode;

@end

NS_ASSUME_NONNULL_END
