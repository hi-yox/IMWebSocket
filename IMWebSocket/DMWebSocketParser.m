//
//  DMWebSocketParser.m
//  IMWebSocket
//
//  Created by jfdreamyang on 2019/3/29.
//  Copyright © 2019 RongCloud. All rights reserved.
//

/* From RFC:
 
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 +-+-+-+-+-------+-+-------------+-------------------------------+
 |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
 |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
 |N|V|V|V|       |S|             |   (if payload len==126/127)   |
 | |1|2|3|       |K|             |                               |
 +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
 |     Extended payload length continued, if payload len == 127  |
 + - - - - - - - - - - - - - - - +-------------------------------+
 |                               |Masking-key, if MASK set to 1  |
 +-------------------------------+-------------------------------+
 | Masking-key (continued)       |          Payload Data         |
 +-------------------------------- - - - - - - - - - - - - - - - +
 :                     Payload Data continued ...                :
 + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
 |                     Payload Data continued ...                |
 +---------------------------------------------------------------+
 */



#import "DMWebSocketParser.h"
#import "DMByteBuffer.h"
#import "DMWebSocket.h"
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonCryptor.h>
#if TARGET_OS_IPHONE
#import <Endian.h>
#else
#import <CoreServices/CoreServices.h>
#endif

static uint8_t const DMFinMask        = 0x80;
static uint8_t const DMOpCodeMask      = 0x0F;
static uint8_t const DMMaskMask         = 0x80;
static uint8_t const DMRSVMask          = 0x70;
static uint8_t const DMRSV1Mask         = 0x40;
static uint8_t const DMPayloadLenMask   = 0x7F;
static int const DMHttpSwitchProtocolCode  = 101;
static int const DMMaxFrameSize       = 32;
static uint8_t const DMFrameHeaderLength = 2;
static uint8_t const DMMAXHeaderLength = 16;

static NSString *const IMWebSocketAppendToSecKeyString = @"258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

@interface DMWebSocketParser ()
{
    BOOL _didHandshake;
    NSString *_securityKey;
    DMByteBuffer *_byteBuffer;
}
@end

@implementation DMWebSocketParser
- (instancetype)init
{
    self = [super init];
    if (self) {
        _didHandshake = NO;
        NSMutableData *keyBytes = [[NSMutableData alloc] initWithLength:16];
        int rc = SecRandomCopyBytes(kSecRandomDefault, keyBytes.length, keyBytes.mutableBytes);
        if (rc == 0) NSLog(@"SecRandomCopyBytes success");
        _securityKey = [keyBytes base64EncodedStringWithOptions:0];
        _byteBuffer = alloc_buffer(4096);
    }
    return self;
}

-(void)append:(NSData *)frame{
    if (!_didHandshake) {
        [self handshake:frame];
    }
    else{
        BOOL _continue = NO;
        if (_byteBuffer->readableBytes > 0) {
            _continue = YES;
        }
        buf_pushs(_byteBuffer, (uint8_t *)frame.bytes, (int)frame.length);
        BOOL process = YES;
        while (process) {
            process = [self parse:_continue];
        }
    }
}

-(BOOL)doContinue{
    return YES;
}

-(BOOL)parse:(BOOL)_continue{
    BOOL isContinue = NO;
    int bytesAvailable = _byteBuffer->readableBytes;
    if (bytesAvailable < 2) {
        return isContinue;
    }
    NSUInteger headerLen = DMMAXHeaderLength;
    if (bytesAvailable < headerLen) {
        headerLen = bytesAvailable;
    }
    uint8_t header[headerLen];
    buf_reads(_byteBuffer, header, (int)headerLen);
    uint8_t isFin = (DMFinMask & header[0]);
    uint8_t receivedOpcode = (DMOpCodeMask & header[0]);
    uint8_t isMasked = (DMMaskMask & header[1]);
    uint8_t payloadLen = (DMPayloadLenMask & header[1]);
    uint8_t offset = DMFrameHeaderLength; //skip past the control opcodes of the frame
    BOOL isControlFrame = (receivedOpcode == DMWebSocketOpCodeClose || receivedOpcode == DMWebSocketOpCodePing);
    BOOL needDecompression = ((DMRSV1Mask & header[0]) > 0);
    if ((isMasked > 0 || (DMRSVMask & header[0]) > 0) && receivedOpcode != DMWebSocketOpCodePong && !needDecompression) {
        NSError *error = [NSError errorWithDomain:@"DMWebSocketParserDomain" code:DMStatusCodeProtocolError userInfo:@{@"desc":@"masked and rsv data is not currently supported"}];
        [self.delegate parserDidError:error];
        return isContinue;
    }
    if (!isControlFrame && (receivedOpcode != DMWebSocketOpCodeBinary && receivedOpcode != DMWebSocketOpCodeContinueFrame &&
                           receivedOpcode != DMWebSocketOpCodeText && receivedOpcode != DMWebSocketOpCodePong && receivedOpcode != DMWebSocketOpCodeClose)) {
        NSError *error = [[NSError alloc]initWithDomain:@"DMWebSocketParserDomain" code:DMStatusCodeProtocolError userInfo:@{@"desc":[NSString stringWithFormat:@"unknown opcode: %@", @(receivedOpcode)]}];
        [self.delegate parserDidError:error];
        return isContinue;
    }
    if (isControlFrame && isFin == 0) {
        NSError *error = [[NSError alloc]initWithDomain:@"DMWebSocketParserDomain" code:DMStatusCodeProtocolError userInfo:@{@"desc":@"control frames can't be fragmented"}];
        [self.delegate parserDidError:error];
        return isContinue;
    }
    NSInteger closeCode = DMStatusCodeNormal;
    if (receivedOpcode == DMWebSocketOpCodeClose) {
        if (payloadLen == 1) {
            closeCode = DMStatusCodeProtocolError;
        }
        else if (payloadLen > 1){
            uint16_t closeCode = 0;
            memcpy(&closeCode, header + offset, 2);
            closeCode = ntohs(closeCode);
            if (closeCode < 1000 || (closeCode > 1003 && closeCode < 1007) || (closeCode > 1013 && closeCode < 3000)) {
                closeCode = DMStatusCodeProtocolError;
            }
        }
        if (payloadLen < 2) {
            NSError *error = [[NSError alloc]initWithDomain:@"DMWebSocketParserDomain" code:closeCode userInfo:@{@"desc":@"connection closed by server"}];
            [self.delegate parserDidError:error];
            return isContinue;
        }
    }
    else if (isControlFrame && payloadLen > 125) {
        NSError *error = [[NSError alloc]initWithDomain:@"DMWebSocketParserDomain" code:DMStatusCodeProtocolError userInfo:@{@"desc":@"control frame using extend payload"}];
        [self.delegate parserDidError:error];
        return isContinue;
    }
    uint64_t dataLength = payloadLen;
    if (dataLength == 127) {
        memcpy(&dataLength, header + offset, 8);
        dataLength = ntohll(dataLength);
        offset += 8;
    } else if (dataLength == 126) {
        uint16_t smallLen = 0;
        memcpy(&smallLen, header + offset, 2);
        dataLength = ntohs(smallLen);
        offset += 2;
    }
    if (bytesAvailable < offset || bytesAvailable - offset < dataLength) {
        // 数据不够，直接跳过
        return isContinue;
    }
    uint64_t appendLength = dataLength;
    if (dataLength > bytesAvailable) {
        appendLength = bytesAvailable - offset;
    }
    if (receivedOpcode == DMWebSocketOpCodeClose && appendLength > 0) {
        uint16_t size = 2;
        offset += size;
        appendLength -= size;
    }
    buf_jump(_byteBuffer, offset);
    uint8_t content[appendLength];
    buf_readslice(_byteBuffer, content, (int)appendLength);
    NSData *data = [NSData dataWithBytes:content length:appendLength];
    if (receivedOpcode == DMWebSocketOpCodeClose) {
        NSString *closeReason = @"connection closed by server";
        NSString *customCloseReason = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        if (customCloseReason) {
            closeReason = customCloseReason;
        }
        else{
            closeCode = DMStatusCodeProtocolError;
        }
        NSError *error = [[NSError alloc]initWithDomain:@"DMWebSocketParserDomain" code:closeCode userInfo:@{@"desc":closeReason}];
        [self.delegate parserDidError:error];
        return isContinue;
    }
    
    if (receivedOpcode == DMWebSocketOpCodePong || receivedOpcode == DMWebSocketOpCodePing) {
        [self.delegate didReceiveMessage:data opCode:receivedOpcode];
        if (_byteBuffer->readableBytes > 0) {
            isContinue = YES;
        }
        return isContinue;
    }

    if (receivedOpcode == DMWebSocketOpCodeBinary) {
        [self.delegate didReceiveMessage:data opCode:receivedOpcode];
        if (_byteBuffer->readableBytes > 0) {
            isContinue = YES;
        }
        return isContinue;
    }
    return isContinue;
}
-(BOOL)handshake:(NSData *)frame{
    NSString *header = [[NSString alloc]initWithData:frame encoding:NSUTF8StringEncoding];
    NSArray <NSString *>*headers = [header componentsSeparatedByString:@"\r\n"];
    BOOL success = NO;
    if (headers.count > 0) {
        NSString *topLine = headers.firstObject;
        NSArray *topLines = [topLine componentsSeparatedByString:@" "];
        NSInteger code = 0;
        if (topLines.count >= 3) {
            code = [topLines[1] integerValue];
        }
        if (code == DMHttpSwitchProtocolCode) {
            // 协议已发生变换
            NSMutableDictionary *info = [NSMutableDictionary new];
            for (NSInteger i=1; i<headers.count; i++) {
                NSString *item = headers[i];
                NSArray <NSString *>*items = [item componentsSeparatedByString:@":"];
                if (items.count >= 2) {
                    NSString *key = [items[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    NSString *value = [items[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    info[key] = value;
                }
            }
            NSString *footprint = info[@"Sec-WebSocket-Accept"];
            NSString * password = [_securityKey stringByAppendingString:IMWebSocketAppendToSecKeyString];
            password = [self sha1ThenBase64:password.UTF8String length:password.length];
            if ([password isEqualToString:footprint]) {
                _didHandshake = YES;
                [self.delegate parserDidConnected];
            }
        }
    }
    return success;
}

-(NSData *)createFrame:(NSData *)message opCode:(UInt8)opCode payloadLength:(NSUInteger)payloadLength{
    NSMutableData *frame = [[NSMutableData alloc]initWithLength:message.length + DMMaxFrameSize];
    if (!frame) {
        return nil;
    }
    uint8_t *frame_buffer = (uint8_t *)[frame mutableBytes];
    frame_buffer[0] = DMFinMask | opCode;
    BOOL useMask = YES;
#ifdef NOMASK
    useMask = NO;
#endif
    if (useMask) {
        // set the mask and header
        frame_buffer[1] |= DMMaskMask;
    }
    size_t frame_buffer_size = 2;
    const uint8_t *unmasked_payload = message.bytes;
    
    if (payloadLength < 126) {
        frame_buffer[1] |= payloadLength;
    } else if (payloadLength <= UINT16_MAX) {
        frame_buffer[1] |= 126;
        *((uint16_t *)(frame_buffer + frame_buffer_size)) = EndianU16_BtoN((uint16_t)payloadLength);
        frame_buffer_size += sizeof(uint16_t);
    } else {
        frame_buffer[1] |= 127;
        *((uint64_t *)(frame_buffer + frame_buffer_size)) = EndianU64_BtoN((uint64_t)payloadLength);
        frame_buffer_size += sizeof(uint64_t);
    }
    
    if (!useMask) {
        for (size_t i = 0; i < payloadLength; i++) {
            frame_buffer[frame_buffer_size] = unmasked_payload[i];
            frame_buffer_size += 1;
        }
    } else {
        uint8_t *mask_key = frame_buffer + frame_buffer_size;
        int genKey = SecRandomCopyBytes(kSecRandomDefault, sizeof(uint32_t), (uint8_t *)mask_key);
        if (genKey) NSLog(@"SecRandomCopyBytes Error");
        frame_buffer_size += sizeof(uint32_t);
        // TODO: could probably optimize this with SIMD
        for (size_t i = 0; i < payloadLength; i++) {
            frame_buffer[frame_buffer_size] = unmasked_payload[i] ^ mask_key[i % sizeof(uint32_t)];
            frame_buffer_size += 1;
        }
    }
    assert(frame_buffer_size <= [frame length]);
    frame.length = frame_buffer_size;
    return frame;
}

-(NSData *)createFrame:(NSData *)message opCode:(UInt8)opCode{
    return [self createFrame:message opCode:opCode payloadLength:message.length];
}

-(NSString *)sha1ThenBase64:(const char *)bytes length:(NSInteger)length{
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(bytes, (CC_LONG)length, digest);
    NSData * result = [NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
    NSString *s = [result base64EncodedStringWithOptions:0];
    return s;
}

-(void)dealloc{
    buf_free(_byteBuffer);
}

@end
