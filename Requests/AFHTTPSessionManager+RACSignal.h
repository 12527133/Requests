//
//  AFHTTPSessionManager+RACSignal.h
//  Requests
//
//  Created by shaohua on 2018/5/24.
//  Copyright © 2018 syang. All rights reserved.
//

#import <AFNetworking/AFHTTPSessionManager.h>

#import "Query.h"

@interface AFHTTPSessionManager (RACSignal)

/*
 RACSignal Protocol:

 query completed | error

 query                      Query
 query.responseObject       json/image/data
 query.response             NSURLResponse
?query.request              NSURLRequest?

 error                      NSError
 error.response             NSURLResponse
 error.query                Query
?error.request              NSURLRequest?

 interceptor 能获取全部信息，进行过滤、解析、拼接等操作后，提供给业务层简单的 responseObject | error
 */

// 兼容老接口
- (RACSignal *)GET:(NSString *)urlPath parameters:(NSDictionary *)parameters;
- (RACSignal *)POST:(NSString *)urlPath parameters:(NSDictionary *)parameters;
- (RACSignal *)PUT:(NSString *)urlPath parameters:(NSDictionary *)parameters;
- (RACSignal *)DELETE:(NSString *)urlPath parameters:(NSDictionary *)parameters;

- (RACSignal *)GET:(NSString *)urlPath parameters:(NSDictionary *)parameters listKey:(NSString *)listKey;
- (RACSignal *)POST:(NSString *)urlPath parameters:(NSDictionary *)parameters listKey:(NSString *)listKey;

- (RACSignal *)GET:(NSString *)urlPath parameters:(NSDictionary *)parameters listKey:(NSString *)listKey modelClass:(Class)modelClass;
- (RACSignal *)POST:(NSString *)urlPath parameters:(NSDictionary *)parameters listKey:(NSString *)listKey modelClass:(Class)modelClass;

- (RACSignal *)POST:(NSString *)urlPath parameters:(NSDictionary *)parameters constructingBodyWithBlock:(void (^)(id<AFMultipartFormData> formData))block;

// 新的统一接口，urlPath 是必须的，所以特别提取了出来
- (RACSignal *)GET:(NSString *)urlPath config:(void (^)(Query *q))config;
- (RACSignal *)POST:(NSString *)urlPath config:(void (^)(Query *q))config;
- (RACSignal *)PUT:(NSString *)urlPath config:(void (^)(Query *q))config;
- (RACSignal *)DELETE:(NSString *)urlPath config:(void (^)(Query *q))config;

- (RACSignal *)send:(Query *)query;

// 每个 manager 一个 interceptor，供其发出的所有请求共享
@property (nonatomic) RACSignal *(^interceptor)(RACSignal *output);

// `transformResponse` allows changes to the response data to be made before it is passed to sendNext
@property (nonatomic) id (^transformResponse)(Query *query, id responseObject);

@end
