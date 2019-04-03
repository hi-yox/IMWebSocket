//
//  DMWebSocket.m
//  IMWebSocket
//
//  Created by jfdreamyang on 2019/3/28.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "DMWebSocket.h"
#import "DMNetworkStreamer.h"
#import "DMWebSocketParser.h"

static NSUInteger const DMMaxSendFrameSize = 4096;

@interface NSURL (IMWebSocket)
- (NSString *)origin;
@end

@implementation NSURL (IMWebSocket)

- (NSString *)origin;
{
    NSString *scheme = [self.scheme lowercaseString];
    if ([scheme isEqualToString:@"wss"]) {
        scheme = @"https";
    } else if ([scheme isEqualToString:@"ws"]) {
        scheme = @"http";
    }
    BOOL portIsDefault = !self.port ||
    ([scheme isEqualToString:@"http"] && self.port.integerValue == 80) ||
    ([scheme isEqualToString:@"https"] && self.port.integerValue == 443);
    if (!portIsDefault) {
        return [NSString stringWithFormat:@"%@://%@:%@", scheme, self.host, self.port];
    } else {
        return [NSString stringWithFormat:@"%@://%@", scheme, self.host];
    }
}

@end


static NSString *const headerWSHostName        = @"Host";
static NSString *const headerWSConnectionName  = @"Connection";
static NSString *const headerWSConnectionValue = @"Upgrade";
static NSString *const headerWSVersionValue    = @"13";
static NSString *const headerWSExtensionName   = @"Sec-WebSocket-Extensions";
static NSString *const headerWSAcceptName      = @"Sec-WebSocket-Accept";

@interface DMWebSocket ()<DMNetworkStreamerDelegate,DMWebSocketParserDelegate>
{
    NSMutableURLRequest *_request;
    NSArray <NSString *>*_protocols;
    DMNetworkStreamer *_streamer;
    DMWebSocketParser *_parser;
    BOOL _connected;
}
@end

@implementation DMWebSocket
- (instancetype)initURLRequest:(NSURLRequest *)request protocols:(nullable NSArray <NSString *> *)protocols
{
    self = [super init];
    if (self) {
        _request = [request mutableCopy];
        NSAssert(request != nil, @"request 不能为空");
        _protocols = protocols;
        _streamer = [[DMNetworkStreamer alloc]initWithRequest:request];
        _streamer.delegate = self;
        _parser = [[DMWebSocketParser alloc]init];
        _parser.delegate = self;
    }
    return self;
}
-(NSData *)header{
    NSURL *_url = _request.URL;
    
    CFHTTPMessageRef request = CFHTTPMessageCreateRequest(NULL, CFSTR("GET"), (__bridge CFURLRef)_url, kCFHTTPVersion1_1);
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Host"), (__bridge CFStringRef)(_url.port ? [NSString stringWithFormat:@"%@:%@", _url.host, _url.port] : _url.host));
   
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Upgrade"), CFSTR("websocket"));
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Connection"), CFSTR("Upgrade"));
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Sec-WebSocket-Key"), (__bridge CFStringRef)_parser.securityKey);
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Sec-WebSocket-Version"), (__bridge CFStringRef)@"13");
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Origin"), (__bridge CFStringRef)_url.origin);
    
    if (_protocols) {
        CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Sec-WebSocket-Protocol"), (__bridge CFStringRef)[_protocols componentsJoinedByString:@", "]);
    }
    CFHTTPMessageSetHeaderFieldValue(request,CFSTR("Sec-WebSocket-Extensions"),CFSTR("permessage-deflate; client_max_window_bits; server_max_window_bits=15"));
    [_request.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        CFHTTPMessageSetHeaderFieldValue(request, (__bridge CFStringRef)key, (__bridge CFStringRef)obj);
    }];
    NSData *message = CFBridgingRelease(CFHTTPMessageCopySerializedMessage(request));
    CFRelease(request);
    
    return message;
}
- (void)connect{
    NSAssert(_streamer != nil, @"没有正确初始化 DMWebSocket");
    [_streamer connect];
}

-(BOOL)sendMessage:(NSData *)message{
    BOOL success = NO;
    if (_connected) {
        success = [self sendMessage:message opCode:DMWebSocketOpCodeBinary];
    }
    return success;
}

-(BOOL)ping:(NSData *)frame{
    BOOL success = NO;
    if (_connected) {
        [self sendMessage:frame opCode:DMWebSocketOpCodePing];
        success = YES;
    }
    return success;
}
-(BOOL)sendMessage:(NSData *)message opCode:(DMWebSocketOpCode)opCode{
    if (message.length > DMMaxSendFrameSize) {
        NSUInteger balance = message.length % DMMaxSendFrameSize;
        NSUInteger count = message.length / DMMaxSendFrameSize;
        for (NSInteger i=0; i<count; i++) {
            NSData * continueFrame;
            if (i == (count - 1)) {
                continueFrame = [NSData dataWithBytes:message.bytes + i*DMMaxSendFrameSize length:DMMaxSendFrameSize + balance];
                 continueFrame = [_parser createFrame:continueFrame opCode:DMWebSocketOpCodeBinary];
            }
            else{
                continueFrame = [NSData dataWithBytes:message.bytes + i*DMMaxSendFrameSize length:DMMaxSendFrameSize];
                continueFrame = [_parser createFrame:continueFrame opCode:DMWebSocketOpCodeContinueFrame];
            }
            [_streamer write:continueFrame];
        }
    }
    else{
        NSData *frame = [_parser createFrame:message opCode:opCode];
        if (!frame) {
            NSLog(@"message too length");
            return NO;
        }
        [_streamer write:frame];
    }
    return YES;
}

#pragma mark - DMNetworkStreamerDelegate
-(void)streamDidReceiveMessage:(NSData *)message{
    [_parser append:message];
}

-(void)streamDidError:(NSError *)error{
    if (!_connected) {
        return;
    }
    [_streamer cleanup];
    if ([self.delegate respondsToSelector:@selector(websocketDidDisconnect:)]) {
        [self.delegate websocketDidDisconnect:self];
    }
}
-(void)streamDidConnect:(DMNetworkStreamerState)state{
    if (state == DMNetworkStreamerStateConnected) {
        [_streamer write:[self header]];
        _connected = YES;
    }
    else{
        _connected = NO;
        if ([self.delegate respondsToSelector:@selector(websocketDidDisconnect:)]) {
            [self.delegate websocketDidDisconnect:self];
        }
    }
}

#pragma mark - DMWebSocketParserDelegate
-(void)parserDidConnected{
    if ([self.delegate respondsToSelector:@selector(webSocketDidConnected:)]) {
        [self.delegate webSocketDidConnected:self];
    }
}

-(void)parserDidError:(NSError *)error{
    NSLog(@"parserDidError %@",error);
    UInt16 code = error.code;
    NSData *message = [NSData dataWithBytes:&code length:2];
    NSData *frame = [_parser createFrame:message opCode:DMWebSocketOpCodeConnectionClose];
    if (_connected) {
        [_streamer write:frame];
        _connected = NO;
    }
}

-(void)didReceiveMessage:(NSData *)message opCode:(UInt8)opCode{
    if (opCode == DMWebSocketOpCodePong) {
        [self.delegate webSocket:self pong:message];
    }
    else if (opCode == DMWebSocketOpCodePing){
        [self.delegate webSocket:self ping:message];
    }
    else {
        [self.delegate webSocket:self didReceiveMessage:message opCode:opCode];
    }
}
-(void)close{
    [self close:0 closeCode:0];
}
-(void)close:(NSInteger)waitTimeout closeCode:(DMStatusCode)closeCode{
    _connected = NO;
    [_streamer cleanup];
}

@end
