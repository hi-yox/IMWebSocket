//
//  DMByteBuffer.c
//  DreamSocket
//
//  Created by jfdreamyang on 2019/3/12.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#include "DMByteBuffer.h"
#include <stdlib.h>
#include <string.h>
DMByteBuffer *alloc_buffer(int capacity){
    DMByteBuffer *buffer = (DMByteBuffer *)malloc(sizeof(DMByteBuffer));
    buffer->content = malloc(capacity);
    buffer->capacity = capacity;
    buffer->raw_capacity = capacity;
    return buffer;
}
bool buf_push(DMByteBuffer *buf,uint8_t value){
    return buf_pushs(buf, &value, 1);
}
bool buf_pushs(DMByteBuffer *buf,uint8_t *value,int count){
    if (buf->readableBytes + count > buf->capacity) {
        // 动态扩容
        int capacity = buf->readableBytes + count + buf->raw_capacity;
        buf->content = realloc(buf->content, capacity);
        buf->capacity = capacity;
    }
    int offset = buf->pos + buf->readableBytes;
    memcpy(buf->content + offset,value,count);
    buf->readableBytes += count;
    return true;
}

bool buf_insert(DMByteBuffer *buf, uint8_t *content, int count){
    if (buf->readableBytes + count > buf->capacity) {
        // 动态扩容
        int capacity = buf->readableBytes + count + buf->raw_capacity;
        buf->content = realloc(buf->content, capacity);
        buf->capacity = capacity;
    }
    memcpy(buf->content + count, buf->content, buf->readableBytes);
    buf->pos = buf->pos + count;
    return true;
}

bool buf_pops(DMByteBuffer *buf,uint8_t *result,int count){
    if (buf->readableBytes < count) {
        return false;
    }
    int offset = buf->readableBytes - count;
    memcpy(result, buf->content + offset, count);
    buf->readableBytes = buf->readableBytes - count;
    return true;
}
int buf_reads(DMByteBuffer *buf,uint8_t *result,int count){
    if (buf->readableBytes < count) {
        return -1;
    }
    else{
        memcpy(result, buf->content + buf->pos, count);
        return count;
    }
}

int buf_readslice(DMByteBuffer *buf,uint8_t *result,int count){
    if (buf->readableBytes < count) {
        return -1;
    }
    else{
        memcpy(result, buf->content + buf->pos, count);
        buf->readableBytes = buf->readableBytes - count;
        buf->pos = buf->pos + count;
        if (buf->readableBytes <= buf->raw_capacity && buf->capacity > buf->raw_capacity) {
            // 注意顺序，这一行很关键
            memcpy(buf->content, buf->content + buf->pos, buf->readableBytes);
            buf->content = realloc(buf->content, buf->raw_capacity);
            buf->capacity = buf->raw_capacity;
            buf->pos = 0;
        }
        if (buf->readableBytes == 0) {
            buf->pos = 0;
        }
        return count;
    }
}

bool buf_jump(DMByteBuffer *buf,int at){
    if (at >= buf->capacity) {
        return false;
    }
    else{
        int offset = at - buf->pos;
        buf->readableBytes = buf->readableBytes - offset;
        buf->pos = at;
        return true;
    }
}

bool buf_move(DMByteBuffer *buf,int offset){
    if (offset + buf->pos < 0 || offset + buf->pos >= buf->capacity) {
        return false;
    }
    buf->pos = buf->pos + offset;
    buf->readableBytes = buf->readableBytes - offset;
    return true;
}

bool buf_free(DMByteBuffer *buf){
    free(buf->content);
    free(buf);
    return true;
}

bool buf_enlarge(DMByteBuffer *buf,int capacity){
    if (capacity <= buf->capacity) {
        return true;
    }
    buf->content = realloc(buf->content, capacity);
    buf->capacity = capacity;
    return true;
}
