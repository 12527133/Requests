//
//  Query.m
//  Requests
//
//  Created by shaohua on 2018/5/10.
//  Copyright © 2018 syang. All rights reserved.
//

#import "Query.h"
#import "NSError+AFNetworking.h"
#import "AFHTTPSessionManager+RACSignal.h"

@interface Query ()

@property (nonatomic) NSMutableDictionary *parameters;
@property (nonatomic) NSMutableDictionary *headers;
@property (nonatomic) id responseObject;
@property (nonatomic) NSURLResponse *response;

@end

@implementation Query

- (instancetype)init {
    if (self = [super init]) {
        _method = HttpMethodGet;
        _parameters = [NSMutableDictionary new];
        _headers = [NSMutableDictionary new];
    }
    return self;
}

- (RACSignal *)send {
    // RACSignal body 包含的操作越多，其被 re-subscribe 时，重复执行的操作也越多
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        AFHTTPSessionManager *manager = self.manager ?: [AFHTTPSessionManager manager];

        if (manager.transformRequest) {
            manager.transformRequest(self);
        }

        // 支持路径中的 {key} 参数:
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\{([^}]+)\\}" options:0 error:0];
        NSString *urlPath = self.urlPath;
        while (1) {
            NSTextCheckingResult *match = [regex firstMatchInString:urlPath options:0 range:NSMakeRange(0, urlPath.length)];
            if (!match) {
                break;
            }
            NSString *key = [urlPath substringWithRange:[match rangeAtIndex:1]]; // "userId"
            NSString *target = [self.parameters[key] description];
            NSAssert(target.length, @"param in urlPath is mandatory");
            urlPath = [urlPath stringByReplacingCharactersInRange:[match rangeAtIndex:0] withString:target]; // "{userId}"
            [self.parameters removeObjectForKey:key];
        };
        // 支持路径中的 {key} 参数: END

        // 注意 isKindOfClass: 与 isMemberOfClass: 的区别
        // Request Part
        if (self.jsonBody) {
            NSAssert([NSJSONSerialization isValidJSONObject:self.jsonBody], @"must be NSArray or NSDictionary!");
            NSAssert(self.multipartBody == nil, @"不应设置 multipart");
            NSAssert(self.parameters.count == 0, @"无视此处参数！");

            NSAssert([manager.requestSerializer isKindOfClass:[AFJSONRequestSerializer class]], @"serializer 不匹配");
        } else {
            NSAssert([manager.requestSerializer isMemberOfClass:[AFHTTPRequestSerializer class]], @"serializer 不匹配");
        }

        // Headers
        [self.headers enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [manager.requestSerializer setValue:obj forHTTPHeaderField:key];
        }];

        void (^ok)(NSURLSessionDataTask *, id) = ^(NSURLSessionDataTask *task, NSObject *responseObject) {
            self.responseDate = [NSDate date];
            if (manager.transformResponse) {
                self.responseObject = manager.transformResponse(self, responseObject);
            } else {
                self.responseObject = responseObject;
            }
            self.response = task.response;

            [subscriber sendNext:self];
            [subscriber sendCompleted];
        };
        void (^err)(NSURLSessionDataTask *, NSError *) = ^(NSURLSessionDataTask *task, NSError *error) {
            error.query = self;
            [subscriber sendError:error];
        };

        if (self.baseURL.length > 0) {
            urlPath = [self.baseURL stringByAppendingString:self.urlPath];
        }

        NSURLSessionDataTask *task = nil;
        switch (self.method) {
            case HttpMethodGet:
                task = [manager GET:urlPath parameters:self.parameters progress:nil success:ok failure:err];
                break;
            case HttpMethodPost:
                if (self.multipartBody) {
                    task = [manager POST:urlPath parameters:self.parameters constructingBodyWithBlock:self.multipartBody progress:nil success:ok failure:err];
                } else if (self.jsonBody) {
                    task = [manager POST:urlPath parameters:self.jsonBody progress:nil success:ok failure:err];
                } else {
                    task = [manager POST:urlPath parameters:self.parameters progress:nil success:ok failure:err];
                }
                break;
            case HttpMethodPut:
                task = [manager PUT:urlPath parameters:self.jsonBody success:ok failure:err];
                break;
            case HttpMethodDelete:
                task = [manager DELETE:urlPath parameters:self.parameters success:ok failure:err];
                break;
        }

        return [RACDisposable disposableWithBlock:^{
            [task cancel];
        }];
    }];
}

@end
