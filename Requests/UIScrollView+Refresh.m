//
//  UIScrollView+Refresh.m
//  Requests
//
//  Created by shaohua on 2018/5/18.
//  Copyright © 2018 syang. All rights reserved.
//

#import "Query.h"
#import "UIScrollView+Refresh.h"

@implementation UIScrollView (Refresh)

- (RACCommand *)showHeader:(RACSignal *)input {
    @weakify(self);
    RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id x) {
        @strongify(self);
        return [input takeUntil:self.rac_willDeallocSignal];
    }];

    [self.mj_header endRefreshing];
    if (!self.mj_header) {
        self.mj_header = [[MJRefreshNormalHeader alloc] init];
    }
    [self.mj_header setRefreshingBlock:^{
        // retain `command`
        [command execute:nil];
    }];

    [[command.executing skip:1] subscribeNext:^(id x) {
        @strongify(self);
        if (![x boolValue]) {
            [self.mj_header endRefreshing];
        }
    }];

    return command;
}

- (void)showHeader:(RACSignal *)input output:(void (^)(RACSignal *, RACSignal *))output {
    RACCommand *command = [self showHeader:input];
    output([command.executionSignals concat], command.errors);
}

- (void)showHeaderAndFooter:(RACSignal *)input output:(void (^)(RACSignal *, RACSignal *))output {
    RACCommand *command = [self showHeader:input];

    @weakify(self);
    @weakify(command);
    RACSignal *reduced = [[command.executionSignals concat] scanWithStart:nil reduce:^id (RACTuple *running, RACTuple *next) {
        @strongify(self);
        NSArray *items = next.first;
        NSDictionary *cursor = next.second;
        int page = [cursor[@"page"] intValue];
        int pages = [cursor[@"pages"] intValue];
        if (page < pages) {
            if (self.mj_footer) {
                [self.mj_footer endRefreshing];
            } else { // 无条件重新创建逻辑上 okay 但 UI 上高度有抖动
                self.mj_footer = [[MJRefreshAutoNormalFooter alloc] init];
            }

            self.mj_footer.refreshingBlock =^{
                @strongify(command);
                Query *query = next.third;
                query.parameters[@"page"] = @(page + 1);
                [command execute:nil];
            };
        } else {
            [self.mj_footer endRefreshingWithNoMoreData];
        }

        if (running) {
            [running.first addObjectsFromArray:items];
            return running;
        }
        return RACTuplePack([NSMutableArray arrayWithArray:items], cursor);
    }];

    output(reduced, command.errors);
}

@end
