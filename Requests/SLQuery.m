//
//  SLQuery.m
//  Requests
//
//  Created by shaohua on 2018/5/17.
//  Copyright © 2018 syang. All rights reserved.
//

#import "SLQuery.h"

@implementation SLQuery

static RACSignal *retrySignal;

+ (void)load {
    retrySignal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
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
}

- (RACSignal *)send:(AFHTTPSessionManager *)manager {
    if (!manager) {
        // 定制 1: 覆盖全局 manager
        manager = [AFHTTPSessionManager manager];
    }
    RACSignal *output = [super send:manager];

    // 定制 2: 全局性地对所有发出的网络请求进行全局性的设置：如认证、解析等
    return [[output materialize] flattenMap:^(RACEvent *event) {
        // [event.error.userInfo[@"result"] isEqualToString:@"login"]
        NSHTTPURLResponse *response = event.error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
        if (event.eventType == RACEventTypeError && response.statusCode == 401) {
            return [retrySignal flattenMap:^RACSignal *(id value) {
                // 成功登录后，再试一次刚才的请求。
                if ([value count]) {
                    [self.headers addEntriesFromDictionary:value];
                    return [super send:manager];
                }
                return [RACSignal error:event.error];
            }];
        }
        return [[RACSignal return:event] dematerialize];
    }];
}

@end