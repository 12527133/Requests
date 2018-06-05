//
//  SLQuery.m
//  Requests
//
//  Created by shaohua on 2018/5/17.
//  Copyright © 2018 syang. All rights reserved.
//

#import <Mantle/Mantle.h>

#import "AppConfig.h"
#import "NSError+AFNetworking.h"
#import "Query.h"
#import "AFHTTPSessionManager+RACSignal.h"

@implementation AppConfig

+ (AFHTTPSessionManager *)manager {
    static AFHTTPSessionManager *manager;
    if (manager) {
        return manager;
    }
    manager = [[AFHTTPSessionManager alloc] initWithBaseURL:nil];

    RACSignal *retrySignal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Auth" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {

        }];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [subscriber sendNext:@{@"Authorization": @"Basic ZGVtbzpkZW1v"}]; // demo:demo
            [subscriber sendCompleted];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [subscriber sendNext:nil];
            [subscriber sendCompleted];
        }]];
        [[UIApplication sharedApplication].delegate.window.rootViewController presentViewController:alert animated:YES completion:^{

        }];
        return nil;
    }];

    manager.interceptor = ^RACSignal *(RACSignal *output) {
        return [[[output materialize] flattenMap:^(RACEvent *event) {
            // 全局认证
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)event.error.response;
            if (event.eventType == RACEventTypeError && response.statusCode == 401) {
                Query *query = event.error.query;
                return [retrySignal flattenMap:^RACSignal *(id value) {
                    // 成功登录后，再试一次刚才的请求。
                    if ([value count]) {
                        [query.headers addEntriesFromDictionary:value];
                        return output;
                    }
                    return [RACSignal error:event.error];
                }];
            }
            return [[RACSignal return:event] dematerialize];
        }] flattenMap:^RACSignal *(NSArray *value) {
            // 全局解析
            Query *query = value.query;
            if (query.modelClass) {
                NSArray *list = value[1];

                NSError *error = nil;
                NSArray *objects = [MTLJSONAdapter modelsOfClass:query.modelClass fromJSONArray:list error:&error];
                if (error) {
                    error.query = query;
                    return [RACSignal error:error];
                }

                // transfer
                query.responseObject = value;
                objects.query = query;
                value.query = nil;
                return [RACSignal return:objects];
            }
            return [RACSignal return:value];
        }];
    };

    return manager;
}

@end
