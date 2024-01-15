//
//  DMNetworkStreamer.m
//  IMWebSocket
//
//  Created by jfdreamyang on 2019/3/28.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "DMNetworkStreamer.h"
#import <Network/Network.h>

@interface DMNetworkStreamer ()
{
    NSURLRequest * _request;
    int g_family;
    dispatch_queue_t _workQueue;
    BOOL _isRunning;
    nw_connection_t _connection;
}
@end

@implementation DMNetworkStreamer

- (instancetype)initWithRequest:(NSURLRequest *)request
{
    self = [super init];
    if (self) {
        _request = request;
        g_family = AF_INET;
        _isRunning = YES;
        _workQueue = dispatch_queue_create("com.jfdream.im.websocket", DISPATCH_QUEUE_SERIAL);
        const char *hostname = _request.URL.host.UTF8String;
        char *port = (char *)[NSString stringWithFormat:@"%d",_request.URL.port.intValue].UTF8String;
        if (strlen(port) == 0) {
            port = "80";
        }
        nw_endpoint_t endpoint = nw_endpoint_create_host(hostname, port);
        nw_parameters_configure_protocol_block_t configure_tls = NW_PARAMETERS_DISABLE_PROTOCOL;
        if ([request.URL.scheme isEqualToString:@"wss"]) {
            configure_tls = ^(nw_protocol_options_t  _Nonnull options) {
                sec_protocol_options_t option = nw_tls_copy_sec_protocol_options(options);
                sec_protocol_options_set_verify_block(option, ^(sec_protocol_metadata_t  _Nonnull metadata, sec_trust_t  _Nonnull trust_ref, sec_protocol_verify_complete_t  _Nonnull complete) {
                    complete(true);
                }, _workQueue);
            };
        }
        nw_parameters_t parameters = nw_parameters_create_secure_tcp(configure_tls,
                                        NW_PARAMETERS_DEFAULT_CONFIGURATION);
        
        
        
        nw_protocol_stack_t protocol_stack = nw_parameters_copy_default_protocol_stack(parameters);
        nw_protocol_options_t ip_options = nw_protocol_stack_copy_internet_protocol(protocol_stack);
        if (g_family == AF_INET) {
            // Force IPv4
            nw_ip_options_set_version(ip_options, nw_ip_version_4);
        } else if (g_family == AF_INET6) {
            // Force IPv6
            nw_ip_options_set_version(ip_options, nw_ip_version_6);
        }
        nw_connection_t connection = nw_connection_create(endpoint, parameters);
        _connection = connection;
    }
    return self;
}
-(void)connect{
    [self startConnection:_connection];
}
-(void)startConnection:(nw_connection_t)connection{
    nw_connection_set_queue(connection, _workQueue);
    nw_connection_set_state_changed_handler(connection, ^(nw_connection_state_t state, nw_error_t error) {
        nw_endpoint_t remote = nw_connection_copy_endpoint(connection);
        errno = error ? nw_error_get_error_code(error) : 0;
        if (state == nw_connection_state_waiting) {
            uint16_t port = nw_endpoint_get_port(remote);
            const char *hostname = nw_endpoint_get_hostname(remote);
            NSLog(@"connect to %s port %u failed, is waiting",hostname?hostname:"127.0.0.1",port);
            [self.delegate streamDidConnect:DMNetworkStreamerStateWaiting];
        } else if (state == nw_connection_state_failed) {
            uint16_t port = nw_endpoint_get_port(remote);
            const char *hostname = nw_endpoint_get_hostname(remote);
            NSLog(@"connect to %s port %u failed",hostname?hostname:"127.0.0.1",port);
            [self.delegate streamDidConnect:DMNetworkStreamerStateFailed];
        } else if (state == nw_connection_state_ready) {
            uint16_t port = nw_endpoint_get_port(remote);
            const char *hostname = nw_endpoint_get_hostname(remote);
            NSLog(@"connect to %s port %u success",hostname?hostname:"127.0.0.1",port);
            [self.delegate streamDidConnect:DMNetworkStreamerStateConnected];
        } else if (state == nw_connection_state_cancelled) {
            uint16_t port = nw_endpoint_get_port(remote);
            const char *hostname = nw_endpoint_get_hostname(remote);
            NSLog(@"cancel connect to %s port %u",hostname?hostname:"127.0.0.1",port);
            [self.delegate streamDidConnect:DMNetworkStreamerStateCancelled];
        }
    });
    nw_connection_start(connection);
    [self readMessageLoop];
}

-(void)cleanup{
    _isRunning = NO;
    dispatch_async(_workQueue, ^{
        nw_connection_cancel(_connection);
    });
}

-(void)readMessageLoop{
    if (!_isRunning) return;
    nw_connection_receive(_connection, 2, 4096, ^(dispatch_data_t  _Nullable content, nw_content_context_t  _Nullable context, bool is_complete, nw_error_t  _Nullable error) {
        if (error) {
            nw_error_domain_t domain = nw_error_get_error_domain(error);
            NSString *desc = [NSString stringWithFormat:@"%@",@(domain)];
            NSError *errorDesc = [NSError errorWithDomain:desc code:nw_error_get_error_code(error) userInfo:nil];
            [self.delegate streamDidError:errorDesc];
            return;
        }
        
        if (is_complete && content == nil && context == nil && error == nil) {
            [self.delegate streamDidError:nil];
            [self cleanup];
            return;
        }
        if (content) {
            NSData *message = [NSData dataWithData:(NSData *)content];
            dispatch_async(self->_workQueue, ^{
                [self.delegate streamDidReceiveMessage:message];
                [self readMessageLoop];
            });
        }
        else{
            [self readMessageLoop];
        }
        
    });
}

-(void)write:(NSData *)frame{
    dispatch_data_t _frame = dispatch_data_create(frame.bytes, frame.length, _workQueue, NULL);
    nw_connection_send(_connection, _frame, NW_CONNECTION_FINAL_MESSAGE_CONTEXT, true, ^(nw_error_t  _Nullable error) {
        if (error) {
            NSLog(@"nw_connection_send error: %@",error);
        }
    });
}

-(void)_write:(NSData *)frame{
    
}


@end
