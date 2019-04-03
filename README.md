# IMWebSocket
High-performance websocket client base on apple network.framework

# features

1. 支持发送不限长度的消息内容（需要 Websocket Server 支持 continueFrame）
2. 使用 apple network.framework 最新网络框架，自动进行断线重连，切换网络设备重连
3. 发送消息精简，只需要传 NSData 的数据即可发送，原则上可以传输任和数据
4. 回调接口精简，比 SRWebSocket,Starscream 简化，更适合上层 app 使用
5. 支持直接和 janus-gateway 等 webrtc 服务端直连（可以设置 protocols）

# Demo

``` objc

// connect
_webSocket = [[DMWebSocket alloc]initURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8008"]] protocols:@[]];
_webSocket.delegate = self;
[_webSocket connect];

// sendMessage
NSString *hello = [@"hello websocket" dataUsingEncoding:NSUTF8StringEncoding];
[_webSocket sendMessage:hello];

// close
[_webSocket close];

```


