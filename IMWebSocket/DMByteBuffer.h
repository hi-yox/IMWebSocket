//
//  DMByteBuffer.h
//  DreamSocket
//
//  Created by jfdreamyang on 2019/3/12.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#ifndef DMByteBuffer_h
#define DMByteBuffer_h

#include <stdio.h>
#include <stdbool.h>

// 自动弹性扩容


typedef struct DMByteBuffer {
    // readslice 时移动的位置
    int pos;
    int readableBytes;
    int capacity;
    uint8_t *content;
    int raw_capacity;
} DMByteBuffer;

/**
 初始化一个 capacity 容量大小的内存区域

 @param capacity 容量大小
 @return buf 对象
 */
DMByteBuffer *alloc_buffer(int capacity);

/**
 将数据追加到最后一个 index

 @param buf buf
 @param value 追加内容
 @param count 追加数量
 @return 是否追加成功
 */
bool buf_pushs(DMByteBuffer *buf,uint8_t *value,int count);

/**
 从最后一个位置开始读取，游标往前游走

 @param buf buf
 @param result 读取结果
 @param count 读取数量
 @return 是否能读取成功
 */
bool buf_pops(DMByteBuffer *buf,uint8_t *result,int count);


/**
 将数据插入到 buf 头部，同时 pos 往右移动 count 位

 @param buf buf
 @param content 插入内容
 @param count 数量
 @return 是否插入成功
 */
bool buf_insert(DMByteBuffer *buf, uint8_t *content, int count);


/**
 读取并游标移动，当剩余可读数为 0 时游标 pos 清 0，使用队列方式进行读取，先进先出

 @param buf buf
 @param result 读取结果
 @param count 读取数量
 @return 返回读取成功的数量
 */
int buf_readslice(DMByteBuffer *buf,uint8_t *result,int count);

/**
 游标不移动

 @param buf 缓冲
 @param result 获取结果
 @param count 获取数量
 @return 获取成功数量
 */
int buf_reads(DMByteBuffer *buf,uint8_t *result,int count);

/**
 移动游标到 at，可读数会剪掉 at + 1

 @param buf buf
 @param at 移动到
 @return 移动成功与否
 */
bool buf_jump(DMByteBuffer *buf,int at);

/**
 将当前游标移动某个数
 
 @param buf buf
 @param at 移动某个数
 @return 移动成功与否
 */
bool buf_move(DMByteBuffer *buf,int at);

/**
 释放资源

 @param buf buf
 @return 释放成功与否
 */
bool buf_free(DMByteBuffer *buf);


/**
 buf 扩容

 @param buf 缓冲区大小
 @param capacity 扩充至多少
 @return 是否扩容成功
 */
bool buf_enlarge(DMByteBuffer *buf,int capacity);

#endif /* DMByteBuffer_h */
