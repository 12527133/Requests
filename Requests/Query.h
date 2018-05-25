//
//  Query.h
//  Requests
//
//  Created by shaohua on 2018/5/10.
//  Copyright © 2018 syang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveObjC/ReactiveObjC.h>
#import <AFNetworking/AFNetworking.h>

typedef NS_ENUM(NSInteger, HttpMethod) {
    GET,
    POST,
    PUT,
    DELETE,
};

typedef NS_ENUM(NSInteger, ResponseType) {
    JSON, // id: NSDictionary or NSArray
    TEXT, // NSString: respects `responseEncoding`
    IMAGE, // UIImage
    BLOB, // NSData
};

@interface Query : NSObject

#pragma mark - The Builder Part 构造对象

- (instancetype)initWithMethod:(HttpMethod)method urlPath:(NSString *)urlPath;

@property (nonatomic, readonly) NSMutableDictionary *headers; // default: {}
@property (nonatomic, readonly) NSMutableDictionary *parameters; // default: {}
@property (nonatomic) void (^multipartBody)(void (^)(id<AFMultipartFormData> formData));
@property (nonatomic) id jsonBody;

@property (nonatomic) ResponseType responseType; // default: JSON
@property (nonatomic) NSStringEncoding responseEncoding; // default: NSUTF8StringEncoding
@property (nonatomic) Class modelClass;
@property (nonatomic) AFHTTPSessionManager *manager;

// defaults
@property (class, nonatomic) RACSignal *(^interceptor)(Query *input, RACSignal *output);

#pragma mark - The Use Part 使用对象
- (RACSignal *)send;

/*
 * 所以请求都需要加入某些 header，如 User-Agent:
   新建一个 manager， 设置其 sessionConfiguration.HTTPAdditionalHeaders
   Authorization 不应使用全局 Header，有安全漏洞，不如 cookie 自动、安全

 * 某些 API 返回 image:
   新建一个 manager，修改其 responseSerializer

 * 只从 cache 读取:
   新建一个 manager，设置其 sessionConfiguration.requestCachePolicy

 */

@end
