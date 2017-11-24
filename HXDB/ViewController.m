//
//  ViewController.m
//  HXDB
//
//  Created by commet on 2017/11/21.
//  Copyright © 2017年 commet. All rights reserved.
//

#import "ViewController.h"
#import "HXDBManager.h"
#import "Person.h"
@interface ViewController ()

@property (nonatomic ,strong) HXDBManager *hxdb;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.hxdb = [HXDBManager shareDB];
    [self.hxdb createTable:@"modelTable" modelClass:NSClassFromString(@"Person") primaryKey:@"identity" excludeProperty:nil];
    
    //插入一个模型
//    Person *person = [[Person alloc] init];
//    person.name = @"PersonName";
//    person.phone = @(111111);
//    person.userData = [@"testData" dataUsingEncoding:NSUTF8StringEncoding];
//    person.identity = 60;
//    person.sex = 0;
//    person.age = 23;
//    person.height = 155.0;
//    person.weight = 233.33333;
//    person.testDic = [NSDictionary dictionary];
//    [self.hxdb insertTable:@"modelTable" model:person excludeProperty:@[@"height",@"weight"] callback:^(NSError *error) {
//        NSLog(@"%@",error);
//    }];
    
//    //插入一组模型
//    NSMutableArray *testModelArr = [NSMutableArray arrayWithCapacity:0];
//    NSMutableArray *exclude = [NSMutableArray arrayWithCapacity:0];
//    NSMutableArray *whereArr = [NSMutableArray arrayWithCapacity:0];
//    for (int i = 0; i < 3; i++) {
//        Person *person = [[Person alloc] init];
//        person.name = @"PersonName";
//        person.phone = @(11111111);
//        person.userData = [@"testData" dataUsingEncoding:NSUTF8StringEncoding];
//        person.identity = i+1;
//        person.sex = 0;
//        person.age = 24;
//        person.height = 170.1;
//        person.weight = 233.33333;
//        person.testDic = [NSDictionary dictionary];
//
//        [testModelArr addObject:person];
//
//        [exclude addObject:@[@"height",@"weight"]];
//        [whereArr addObject:@{@"where identity = ?" : @[[NSNumber numberWithInteger:person.identity]]}];
//    }
//    [self.hxdb insertTableInTransaction:@"modelTable" modelArr:testModelArr excludeProperty:exclude callback:^(NSError *error) {
//        NSLog(@"%@",error);;
//    }];
    
    //插入一条数据
//    NSDictionary *paraDict = @{@"name":@"commet",@"phone":@"13535230987",@"identity":@"999"};
//
//    [self.hxdb insertTable:@"modelTable" param:paraDict callback:^(NSError *error) {
//        if(error) NSLog(@"插入表失败：%@",error);
//    }];

    //更新模型数据
//    [self.hxdb updateTable:@"modelTable" model:person excludeProperty:@[@"name",@"userData",@"identity",@"age"] whereDict:@{@"where identity = ?" : @[@60]} callback:^(NSError *error) {
//        NSLog(@"%@",error);
//    }];
    
    //批量更新模型
//    [self.hxdb updateTableInTransaction:@"modelTable" modelArr:testModelArr excludeProperty:exclude whereArrs:whereArr callback:^(NSError *error) {
//        NSLog(@"%@",error);
//    }];
    
    //更新单个记录
//    NSDictionary *paraDict = @{@"name":@"commet",@"phone":@"13535230987"};
//
//    [self.hxdb updateTable:@"modelTable" param:paraDict whereDict:@{@"where identity = ?" : @[@1]} callback:^(NSError *error) {
//        if(error) NSLog(@"%@",error);
//    }];
    
    //删除单条件记录
//    [self.hxdb deleteTable:@"modelTable" whereDict:@{@"where age = ?" : @[@24]} callback:^(NSError *error) {
//        if(error) NSLog(@"%@",error);
//    }];
    
    //批量删除
//    NSMutableArray *deleteWhere = [NSMutableArray array];
//    [deleteWhere addObject:@{@"where sex = ?" : @[@0]}];
//    [deleteWhere addObject:@{@"where sex = ? and name = ?":@[@1,@"commet"]}];
//    [deleteWhere addObject:@{@"where phone = ?" : @[@"305757732"]}];
//    [self.hxdb deleteTableInTransaction:@"modelTable" whereArrs:deleteWhere callback:^(NSError *error) {
//
//    }];
    
    //根据条件查询有多少条记录
//    int count = [self.hxdb itemCountForTable:@"modelTable" whereDict:@{@"where sex = ?" : @[@1]}];
//    NSLog(@"count = %d",count);
    
    //查询模型
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSMutableArray *rsArr = [self.hxdb queryTable:@"modelTable" modelClass:NSClassFromString(@"Person") excludeProperty:nil whereDict:nil callback:^(NSError *error) {
            
        }];
        NSLog(@"rs:%@",rsArr);
    });
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
