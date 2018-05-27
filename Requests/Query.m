//
//  Query.m
//  Requests
//
//  Created by shaohua on 2018/5/10.
//  Copyright © 2018 syang. All rights reserved.
//

#import "Query.h"

@interface Query ()

@property (nonatomic) NSMutableDictionary *parameters;
@property (nonatomic) NSMutableDictionary *headers;
@property (nonatomic) void (^block)(id<AFMultipartFormData>);

@end

@implementation Query

- (instancetype)init {
    if (self = [super init]) {
        _method = GET;
        _parameters = [NSMutableDictionary new];
        _headers = [NSMutableDictionary new];
        _responseEncoding = NSUTF8StringEncoding;
        _responseType = JSON;
    }
    return self;
}

- (void)dealloc {
    NSLog(@"dealloc %@", self);
}

- (void (^)(void (^)(id<AFMultipartFormData>)))multipartBody {
    return ^(void (^block)(id<AFMultipartFormData>)) {
        self.block = block;
    };
}

- (RACSignal *)send {
    // RACSignal body 包含的操作越多，其被 re-subscribe 时，重复执行的操作也越多
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        AFHTTPSessionManager *manager = self.manager ?: [AFHTTPSessionManager manager];

        // Request Part
        if (self.jsonBody) {
            NSCAssert([NSJSONSerialization isValidJSONObject:self.jsonBody], @"NSArray or NSDictionary!");
            NSCAssert(self.block == nil, @"WTF");
            if (![manager.requestSerializer isMemberOfClass:[AFJSONRequestSerializer class]]) {
                manager.requestSerializer = [AFJSONRequestSerializer serializer];
            }
        } else {
            if (![manager.requestSerializer isMemberOfClass:[AFHTTPRequestSerializer class]]) {
                manager.requestSerializer = [AFHTTPRequestSerializer serializer];
            }
        }

        // Response Part
        switch (self.responseType) {
        case JSON:
            if (![manager.responseSerializer isMemberOfClass:[AFJSONResponseSerializer class]]) {
                manager.responseSerializer = [AFJSONResponseSerializer serializer];
            }
            break;
        case IMAGE:
            if (![manager.responseSerializer isMemberOfClass:[AFImageResponseSerializer class]]) {
                manager.responseSerializer = [AFImageResponseSerializer serializer];
            }
            break;
        case TEXT:
        case BLOB:
            if (![manager.responseSerializer isMemberOfClass:[AFHTTPResponseSerializer class]]) {
                manager.responseSerializer = [AFHTTPResponseSerializer serializer];
            }
        }

        // Headers
        [self.headers enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [manager.requestSerializer setValue:obj forHTTPHeaderField:key];
        }];

        void (^ok)(NSURLSessionDataTask *, id) = ^(NSURLSessionDataTask *task, id responseObject) {
            if (self.responseType == TEXT) {
                responseObject = [[NSString alloc] initWithData:responseObject encoding:self.responseEncoding];
            }
            [subscriber sendNext:RACTuplePack(responseObject, task.response, self)];
            [subscriber sendCompleted];
        };
        void (^err)(NSURLSessionDataTask *, NSError *) = ^(NSURLSessionDataTask *task, NSError *error) {
            [subscriber sendError:error];
        };

        NSURLSessionDataTask *task = nil;
        switch (self.method) {
            case GET:
                task = [manager GET:self.urlPath parameters:self.parameters progress:nil success:ok failure:err];
                break;
            case POST:
                if (self.block) {
                    task = [manager POST:self.urlPath parameters:self.parameters constructingBodyWithBlock:self.block progress:nil success:ok failure:err];
                } else if (self.jsonBody) {
                    task = [manager POST:self.urlPath parameters:self.jsonBody progress:nil success:ok failure:err];
                } else {
                    task = [manager POST:self.urlPath parameters:self.parameters progress:nil success:ok failure:err];
                }
                break;
            case PUT:
                task = [manager PUT:self.urlPath parameters:self.jsonBody success:ok failure:err];
                break;
            case DELETE:
                task = [manager DELETE:self.urlPath parameters:self.parameters success:ok failure:err];
                break;
        }

        return [RACDisposable disposableWithBlock:^{
            [task cancel];
        }];
    }];
}

@end
