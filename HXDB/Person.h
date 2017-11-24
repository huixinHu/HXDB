//
//  Person.h
//  HXDB
//
//  Created by commet on 2017/11/23.
//  Copyright © 2017年 commet. All rights reserved.
//

#import <Foundation/Foundation.h>
@class Person;
@interface Person : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSNumber *phone;
@property (nonatomic, strong) NSData *userData;
@property (nonatomic, assign) NSInteger identity;
@property (nonatomic, assign) BOOL sex;
@property (nonatomic, assign) int age;
@property (nonatomic, assign) float height;  
@property (nonatomic, assign) double weight;

@property (nonatomic, strong) NSDictionary *testDic;
@property (nonatomic, strong) NSSet *testSet;
@property (nonatomic, strong) NSArray *testArray;
@property (nonatomic, strong) Person *testPerson;
@end
