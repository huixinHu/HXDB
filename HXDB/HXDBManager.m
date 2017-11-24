//
//  HXDBManager.m
//  XiaoYa
//
//  Created by commet on 2017/9/25.
//  Copyright © 2017年 commet. All rights reserved.
//

#import "HXDBManager.h"
#import "FMDB.h"
#import <CommonCrypto/CommonCrypto.h>
#import <objc/runtime.h>

#define kMaxPageCount 50//分页条数

@interface HXDBManager ()<NSCopying,NSMutableCopying>
@property (nonatomic ,strong) FMDatabaseQueue *dbQueue;
@property (nonatomic ,strong) NSString *dbPath;
@property (nonatomic ,strong) dispatch_queue_t queue;
@property (nonatomic, strong)FMDatabase *db;
@end

@implementation HXDBManager
static NSString *HXDBErrorDomain = @"com.comment.hxdbdomain";
static HXDBManager *sharedManager = nil;

+ (instancetype)shareDB{
    return [self shareDB:nil dbPath:nil];
}

+ (instancetype)shareDB:(NSString *)dbName{
    return [self shareDB:dbName dbPath:nil];
}

+ (instancetype)shareDB:(NSString *)dbName dbPath:(NSString *)dbpath{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[super allocWithZone:NULL] initWithFilePath:dbpath dbName:dbName];
    });
    return sharedManager;
}

+ (id)allocWithZone:(struct _NSZone *)zone{
    return [HXDBManager shareDB] ;
}

- (id)copyWithZone:(NSZone *)zone{
    return [HXDBManager shareDB] ;//return _instance;
}

- (id)mutableCopyWithZone:(NSZone *)zone{
    return [HXDBManager shareDB] ;
}

- (instancetype)initWithFilePath:(NSString *)path dbName:(NSString *)dbName{
    if (self = [super init]) {

        [self changeFilePath:path dbName:dbName];
    }
    return self;
}

//切换用户就要切换数据库//这里应该根据用户信息md5建一个路径
- (void)changeFilePath:(NSString *)path dbName:(NSString *)dbName{
    if ([self.db open]) {//切换数据库要先关闭旧用户数据库
        [self.db close];
    }
    NSString *filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)lastObject];
    if (path) {
        filePath = [filePath stringByAppendingPathComponent:path];
    }
    
    NSFileManager *fmManager = [NSFileManager defaultManager];
    BOOL isDir;
    BOOL exit = [fmManager fileExistsAtPath:filePath isDirectory:&isDir];//指示一个文件或者一个路径是否存在于特定的路径之下
    if (!exit || !isDir) {
        [fmManager createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if (!dbName) {
        dbName = @"XiaoYa.sqlite";
    }
    self.dbPath = [filePath stringByAppendingPathComponent:dbName];
    NSLog(@"dataBasePath:%@",filePath);
    
    self.dbQueue = [FMDatabaseQueue databaseQueueWithPath:self.dbPath];
    self.db = [self.dbQueue valueForKey:@"_db"];
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        BOOL result = [db executeUpdate:@"PRAGMA foreign_keys=ON;"];
        [db setShouldCacheStatements:YES];//开启缓存
        if (!result) {
            NSLog(@"外键开启失败");
        }
    }];
}

//拼接"?,?,?,?..."格式字符串
- (NSString *)appendKeys:(NSInteger)count {
    NSMutableString *string = [NSMutableString new];
    for (int i = 0; i < count; i++) {
        [string appendString:@"?"];
        if (i + 1 != count) {
            [string appendString:@","];
        }
    }
    return string;
}

#pragma mark runtime
//模型转字典 propertyArr：模型中不需要转化的属性数组
- (NSDictionary *)modelToDictionary:(Class)cls excludeProperty:(NSArray *)propertyArr{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:0];
    u_int count;
    objc_property_t *properties = class_copyPropertyList(cls, &count);
    for (int i = 0; i < count; i++) {
        NSString *pName = [NSString stringWithCString:property_getName(properties[i]) encoding:NSUTF8StringEncoding];
        if ([propertyArr containsObject:pName]) continue;
        NSString *pType = [NSString stringWithCString:property_getAttributes(properties[i]) encoding:NSUTF8StringEncoding];
        NSString *sqlType = [self ocTypeToSqlType:pType];
        if (sqlType) {
            [dict setObject:sqlType forKey:pName];
        }
    }
    free(properties);
    return dict;
}

//oc数据类型转sql数据类型
- (NSString *)ocTypeToSqlType:(NSString *)ocType{
    NSString *resultStr = nil;
    if ([ocType hasPrefix:@"T@\"NSString\""]) {
        resultStr = SQL_TEXT;
    } else if ([ocType hasPrefix:@"T@\"NSData\""]) {
        resultStr = SQL_BLOB;
    } else if ([ocType hasPrefix:@"Ti"]||[ocType hasPrefix:@"TI"]||[ocType hasPrefix:@"Ts"]||[ocType hasPrefix:@"TS"]||[ocType hasPrefix:@"T@\"NSNumber\""]||[ocType hasPrefix:@"TB"]||[ocType hasPrefix:@"Tq"]||[ocType hasPrefix:@"TQ"]) {
        resultStr = SQL_INTEGER;
    } else if ([ocType hasPrefix:@"Tf"] || [ocType hasPrefix:@"Td"]){
        resultStr= SQL_REAL;
    }
    
    return resultStr;
}

//得到model属性的名称和值
- (NSMutableDictionary *)getModelPropertyKeyValue:(id)model tableName:(NSString *)tableName excludeProperty:(NSArray *)colArr{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:0];
    u_int count;
    objc_property_t *properties = class_copyPropertyList([model class], &count);
    for (int i = 0; i < count; i++) {
        NSString *pName = [NSString stringWithCString:property_getName(properties[i]) encoding:NSUTF8StringEncoding];
        if (colArr && [colArr containsObject:pName]) continue;
        id pValue = [model valueForKey:pName];
        if (pValue) {
            [dict setObject:pValue forKey:pName];
        }
    }
    free(properties);
    return dict;
}

//表是否存在
- (BOOL)isExistTable:(FMDatabase *)db table:(NSString *)tableName{
    return [db tableExists:tableName];
}

#pragma mark 创建表
//根据sql语句创建表
- (BOOL)tableCreate:(NSString *)sql table:(NSString *)tableName{
    if (sql.length == 0) {
        NSLog(@"sql语句不能为空，创建表失败");
        return NO;
    }
    
    __block BOOL result = NO;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        if ([db open]){//检查数据库是否打开
            if ([self isExistTable:db table:tableName]){//检查表是否已经存在
                result = YES;
            } else{
                result = [db executeUpdate:sql];//创建表
            }
        } else{
            result = NO;
        }
        if (!result) {
            NSLog(@"%@",[db lastError]);
        }
    }];
    NSLog(@"%@", result ? [NSString stringWithFormat:@"创建表 %@成功",tableName] : [NSString stringWithFormat:@"创建表 %@失败",tableName]);
    return result;
}

//根据传入的参数拼接创建表sql语句，只支持设置字段名、字段类型、主键。dict：key 字段名、value 字段类型；pk：主键，可为nil。
- (BOOL)createTable:(NSString *)tableName colDict:(NSDictionary *)dict primaryKey:(NSString *)pk{
    NSAssert((dict != nil)&&(dict.count > 0) , @"创建表：dict 参数无效");
    if (tableName == nil ||(dict == nil) || (dict.count == 0)) {
        return NO;
    }
    __block BOOL result = NO;
    NSMutableString *sqlStr = [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (",tableName];
    NSArray *keysArr = [dict allKeys];
    [keysArr enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [sqlStr appendFormat:@"%@ %@,",obj,dict[obj]];
        if (pk && ([obj isEqualToString:pk])) {
            [sqlStr insertString:@" PRIMARY KEY" atIndex:sqlStr.length-1];
        }
    }];
    [sqlStr deleteCharactersInRange:NSMakeRange(sqlStr.length - 1, 1)];
    [sqlStr appendString:@")"];
    
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        if ([db open]) {
            result = [db executeUpdate:sqlStr];
        }
    }];
    NSLog(@"%@", result ? [NSString stringWithFormat:@"创建表 %@成功",tableName] : [NSString stringWithFormat:@"创建表 %@失败",tableName]);
    return result;
}

//根据模型类创建表
//colArr 模型中不需要转化为表字段的属性数组
- (BOOL)createTable:(NSString *)tableName modelClass:(Class)cls primaryKey:(NSString *)pk excludeProperty:(NSArray *)colArr{
    if (tableName == nil || cls == nil || [colArr containsObject:pk]) {
        return NO;
    }
    NSDictionary *dict = [self modelToDictionary:cls excludeProperty:colArr];
    return [self createTable:tableName colDict:dict primaryKey:pk];
}

#pragma mark 删除表
- (void)dropTable:(NSString *)tableName callback:(void(^)(NSError *error ))block{
    if (tableName == nil) {
        if (block) {
            NSError *error = [self errorWithErrorCode:2000];
            block(error);
        }
        return;
    }
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *sqlstr = [NSString stringWithFormat:@"DROP TABLE %@", tableName];
        BOOL result = [db executeUpdate:sqlstr];
        if (!result) {
            if (block) {
                block([db lastError]);
            }
        }
    }];
}

#pragma mark 插入
//插入模型
- (void)insertTable:(NSString *)tableName model:(id)model excludeProperty:(NSArray *)colArr callback:(void(^)(NSError *error ))block{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:0];
    dict = [self getModelPropertyKeyValue:model tableName:tableName excludeProperty:colArr];
    [self insertTable:tableName param:dict callback:block];
}

//批量插入模型
- (void)insertTableInTransaction:(NSString *)tableName modelArr:(NSArray <id>*)modelArr excludeProperty:(NSArray <NSArray *>*)colArr callback:(void(^)(NSError *error ))block{
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:0];
    [modelArr enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict;
        if (idx < colArr.count) {
            dict = [self getModelPropertyKeyValue:obj tableName:tableName excludeProperty:colArr[idx]];
        } else {
            dict = [self getModelPropertyKeyValue:obj tableName:tableName excludeProperty:nil];
        }
        [arr addObject:dict];
    }];
    [self insertTableInTransaction:tableName paramArr:arr callback:block];
}

//插入单条数据。paraDict：key 字段名、value 字段值；block：回调。有回调就不需要返回BOOL值（表示是否插入成功）
- (void)insertTable:(NSString *)tableName param:(NSDictionary *)paraDict callback:(void(^)(NSError *error ))block{
    if (tableName == nil || paraDict == nil || paraDict.count == 0) {
        if (block) {
            NSError *error = [self errorWithErrorCode:2000];
            block(error);
        }
        return;
    }
    
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        if (![self isExistTable:db table:tableName]) {
            if (block) {
                NSError *error = [self errorWithErrorCode:2001];
                block(error);
            }
            return;
        }
        if ([db open]){
            NSArray *columns = [self tableColumnsArr:tableName db:db];//表字段
            NSMutableString *sqlStr = [NSMutableString stringWithFormat:@"INSERT INTO %@ (",tableName];
            NSArray *keys = [paraDict allKeys];
            NSMutableArray *values = [NSMutableArray arrayWithCapacity:0];
            [keys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([columns containsObject:obj]) {
                    [sqlStr appendFormat:@"%@ ,",obj];
                    [values addObject:paraDict[obj]];
                }
            }];
            [sqlStr deleteCharactersInRange:NSMakeRange(sqlStr.length - 1, 1)];
            [sqlStr appendString:@")"];
            
            [sqlStr appendFormat:@" VALUES (%@)",[self appendKeys:values.count]];
            BOOL result = [db executeUpdate:sqlStr withArgumentsInArray:values];
            if (!result) {
                if (block) {
                    block([db lastError]);
                }
            }
            NSLog(result ? @"插入成功" : @"插入失败");
        }
    }];
}

//批量插入数据
- (void)insertTableInTransaction:(NSString *)tableName paramArr:(NSArray <NSDictionary *>*)paraArr callback:(void(^)(NSError *error))block{
    if (tableName == nil || paraArr == nil || paraArr.count == 0){
        if (block) {
            NSError *error = [self errorWithErrorCode:2000];
            block(error);
        }
        return;
    }
    [self.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if (![self isExistTable:db table:tableName]) {
            if (block) {
                NSError *error = [self errorWithErrorCode:2001];
                block(error);
            }
            return;
        }
        if ([db open]) {
            [db setShouldCacheStatements:YES];//开启缓存
            NSArray *columns = [self tableColumnsArr:tableName db:db];
            [paraArr enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull paraDict, NSUInteger idx, BOOL * _Nonnull stop) {
                NSMutableString *sqlStr = [NSMutableString stringWithFormat:@"INSERT INTO %@ (",tableName];
                NSArray *keys = [paraDict allKeys];
                NSMutableArray *values = [NSMutableArray arrayWithCapacity:0];
                [keys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if ([columns containsObject:obj]) {
                        [sqlStr appendFormat:@"%@ ,",obj];
                        [values addObject:paraDict[obj]];
                    }
                }];
                [sqlStr deleteCharactersInRange:NSMakeRange(sqlStr.length - 1, 1)];
                [sqlStr appendString:@")"];
                
                [sqlStr appendFormat:@" VALUES (%@)",[self appendKeys:values.count]];
                BOOL result = [db executeUpdate:sqlStr withArgumentsInArray:values];
                if (!result) {
                    if (block) {
                        block([db lastError]);
                    }
                    *rollback = YES;
                    *stop = YES;
                    return;
                }
            }];
        }
    }];
}

#pragma mark 更新
//更新模型
- (void)updateTable:(NSString *)tableName model:(id)model excludeProperty:(NSArray *)colArr whereDict:(NSDictionary *)where callback:(void(^)(NSError *error ))block{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:0];
    dict = [self getModelPropertyKeyValue:model tableName:tableName excludeProperty:colArr];
    [self updateTable:tableName param:dict whereDict:where callback:block];
}

//批量更新模型
- (void)updateTableInTransaction:(NSString *)tableName modelArr:(NSArray <id>*)modelArr excludeProperty:(NSArray <NSArray *>*)colArr whereArrs:(NSArray<NSDictionary *> *)whereArr callback:(void (^)(NSError *))block{
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:0];
    [modelArr enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict;
        if (idx < colArr.count) {
            dict = [self getModelPropertyKeyValue:obj tableName:tableName excludeProperty:colArr[idx]];
        } else {
            dict = [self getModelPropertyKeyValue:obj tableName:tableName excludeProperty:nil];
        }
        [arr addObject:dict];
    }];
    [self updateTableInTransaction:tableName paramArr:arr whereArrs:whereArr callback:block];
}

//paraDict：key 字段名、value 字段值；如果where传空，就更新整个表
- (void)updateTable:(NSString *)tableName param:(NSDictionary *)paraDict whereDict:(NSDictionary *)where callback:(void(^)(NSError *error ))block{
    if (tableName == nil || paraDict == nil || paraDict.count == 0){
        if (block) {
            NSError *error = [self errorWithErrorCode:2000];
            block(error);
        }
        return;
    }
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        if (![self isExistTable:db table:tableName]) {
            if (block) {
                NSError *error = [self errorWithErrorCode:2001];
                block(error);
            }
            return;
        }
        if ([db open]) {
            NSArray *columns = [self tableColumnsArr:tableName db:db];
            NSMutableString *sqlStr = [NSMutableString stringWithFormat:@"UPDATE %@ SET ",tableName];
            NSArray *keys = [paraDict allKeys];
            NSMutableArray *values = [NSMutableArray arrayWithCapacity:0];
            [keys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([columns containsObject:obj]) {
                    [sqlStr appendFormat:@"%@ = ?,",obj];
                    [values addObject:paraDict[obj]];
                }
            }];
            [sqlStr deleteCharactersInRange:NSMakeRange(sqlStr.length - 1, 1)];
            if (where.count > 0) {
                [where enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                    [sqlStr appendFormat:@" %@",key];
                    [values addObjectsFromArray:obj];
                }];
            }
            
            BOOL result = [db executeUpdate:sqlStr withArgumentsInArray:values];
            if (!result) {
                if (block) {
                    block([db lastError]);
                }
            }
        }
    }];
}

- (void)updateTableInTransaction:(NSString *)tableName paramArr:(NSArray <NSDictionary *>*)paraArr whereArrs:(NSArray <NSDictionary *>*)whereArr callback:(void(^)(NSError *error))block{
    if (tableName == nil || paraArr == nil || paraArr.count == 0 || paraArr.count != whereArr.count){
        if (block) {
            NSError *error = [self errorWithErrorCode:2000];
            block(error);
        }
        return;
    }
    [self.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if (![self isExistTable:db table:tableName]) {
            if (block) {
                NSError *error = [self errorWithErrorCode:2001];
                block(error);
            }
            return;
        }
        if ([db open]) {
            NSArray *columns = [self tableColumnsArr:tableName db:db];
            [paraArr enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull paraDict, NSUInteger idx, BOOL * _Nonnull stop) {
                NSMutableString *sqlStr = [NSMutableString stringWithFormat:@"UPDATE %@ SET ",tableName];
                NSArray *keys = [paraDict allKeys];
                NSMutableArray *values = [NSMutableArray arrayWithCapacity:0];
                [keys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if ([columns containsObject:obj]) {
                        [sqlStr appendFormat:@"%@ = ?,",obj];
                        [values addObject:paraDict[obj]];
                    }
                }];
                [sqlStr deleteCharactersInRange:NSMakeRange(sqlStr.length - 1, 1)];
                
                if (whereArr[idx].count > 0) {
                    NSDictionary *where = whereArr[idx];
                    if (where.count > 0) {
                        [where enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                            [sqlStr appendFormat:@" %@",key];
                            [values addObjectsFromArray:obj];
                        }];
                        //存在where子句才执行更新。由于这个方法是对同一个表进行批量更新，如果有其中一个事务没有where子句（更新整表），那么批量更新就没意义了
                        BOOL result = [db executeUpdate:sqlStr withArgumentsInArray:values];
                        if (!result) {
                            if (block) {
                                block([db lastError]);
                            }
                            *rollback = YES;
                            *stop = YES;
                            return;
                        }
                    }
                    else {//没有where子句
                        if (block) {
                            NSError *error = [self errorWithErrorCode:2002];
                            block(error);
                        }
                        *rollback = YES;
                        *stop = YES;
                        return;
                    }
                }
            }];
        }
    }];
}

#pragma mark 删除
//如果where为空，就删除整表记录
- (void)deleteTable:(NSString *)tableName whereDict:(NSDictionary *)where callback:(void(^)(NSError *error))block{
    if (tableName == nil) {
        if (block) {
            NSError *error = [self errorWithErrorCode:2000];
            block(error);
        }
        return;
    }
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        if (![self isExistTable:db table:tableName]) {
            if (block) {
                NSError *error = [self errorWithErrorCode:2001];
                block(error);
            }
            return;
        }
        if ([db open]) {
            NSMutableString *sqlStr = [NSMutableString stringWithFormat:@"DELETE FROM %@ ",tableName];
            NSMutableArray *values = [NSMutableArray arrayWithCapacity:0];
            if (where.count > 0) {
                [where enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                    [sqlStr appendFormat:@" %@",key];
                    [values addObjectsFromArray:obj];
                }];
            }
            
            BOOL result = [db executeUpdate:sqlStr withArgumentsInArray:values];
            if (!result) {
                if (block) {
                    block([db lastError]);
                }
            }
        }
    }];
}

- (void)deleteTableInTransaction:(NSString *)tableName whereArrs:(NSArray <NSDictionary *>*)whereArrs callback:(void(^)(NSError *error))block{
    if (tableName == nil){
        if (block) {
            NSError *error = [self errorWithErrorCode:2000];
            block(error);
        }
        return;
    }
    [self.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if (![self isExistTable:db table:tableName]) {
            if (block) {
                NSError *error = [self errorWithErrorCode:2001];
                block(error);
            }
            return;
        }
        if ([db open]) {
            [whereArrs enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSMutableString *sqlStr = [NSMutableString stringWithFormat:@"DELETE FROM %@ ",tableName];
                NSMutableArray *values = [NSMutableArray arrayWithCapacity:0];
                if (obj.count > 0) {
                    [obj enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                        [sqlStr appendFormat:@" %@",key];
                        [values addObjectsFromArray:obj];
                    }];
                }
                BOOL result = [db executeUpdate:sqlStr withArgumentsInArray:values];
                if (!result) {
                    if (block) {
                        block([db lastError]);
                    }
                    *rollback = YES;
                    *stop = YES;
                    return;
                }

            }];
        }
    }];
}

#pragma mark 直接传入sql语句进行增删改
//如果是绑定语法的需要传入para
- (void)updateWithSqlStat:(NSString *)sql callback:(void(^)(NSError *error ))block{
    if (sql.length == 0 || !sql) {
        if (block) {
            NSError *error = [self errorWithErrorCode:2000];
            block(error);
        }
        return;
    }

    [self.dbQueue inDatabase:^(FMDatabase *db) {
        if ([db open]) {
            BOOL result = [db executeUpdate:sql];
            if (!result) {
                if (block) {
                    block([db lastError]);
                }
            }
        }
    }];
}

- (void)updateWithSqlStatInTransaction:(NSArray <NSString *> *)sqlArr callback:(void(^)(NSError *error))block{
    if (sqlArr.count == 0 || !sqlArr) {
        if (block) {
            NSError *error = [self errorWithErrorCode:2000];
            block(error);
        }
        return;
    }

    [self.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if ([db open]) {
            [sqlArr enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                BOOL result = [db executeUpdate:obj];
                if (!result) {
                    if (block) {
                        block([db lastError]);
                    }
                    *rollback = YES;
                    *stop = YES;
                    return;
                }
            }];
        }
    }];
}

#pragma mark 查询
//根据条件查询有多少条数据
- (int)itemCountForTable:(NSString *)tableName whereDict:(NSDictionary *)where{
    NSMutableString *sqlStr = [NSMutableString stringWithFormat:@"SELECT count(*) from %@",tableName];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:0];
    if (where.count > 0) {
        [where enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [sqlStr appendFormat:@" %@",key];
            [values addObjectsFromArray:obj];
        }];
    }
    
    __block int count = 0;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs;
        if (values.count == 0) {
            rs = [db executeQuery:sqlStr];
        } else{
            rs = [db executeQuery:sqlStr withArgumentsInArray:values];
        }
        while ([rs next]) {
            count = [rs intForColumnIndex:0];
        }
        [rs close];
    }];
    return count;
}

//查询模型
- (NSMutableArray *)queryTable:(NSString *)tableName modelClass:(Class)cls excludeProperty:(NSArray *)colArr whereDict:(NSDictionary *)where callback:(void(^)(NSError *error))block{
    NSDictionary *dict = [self modelToDictionary:cls excludeProperty:colArr];
    return [self queryTable:tableName columns:dict whereDict:where callback:block];
}

//查询单条
- (NSMutableArray *)queryTable:(NSString *)tableName columns:(NSDictionary *)columnDict whereDict:(NSDictionary *)where callback:(void(^)(NSError *error))block{
    if (tableName == nil || columnDict == nil || columnDict.count == 0){
        if (block) {
            NSError *error = [self errorWithErrorCode:2000];
            block(error);
        }
        return nil;
    }
    NSMutableArray *dataArr = [NSMutableArray array];
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        if (![self isExistTable:db table:tableName]) {
            if (block) {
                NSError *error = [self errorWithErrorCode:2001];
                block(error);
            }
            return;
        }
        if ([db open]) {
            NSArray *columns = [self tableColumnsArr:tableName db:db];
            NSMutableString *sqlStr = [NSMutableString stringWithString:@"SELECT "];
            NSMutableArray *keys = [NSMutableArray arrayWithCapacity:0];
            [columnDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                if ([columns containsObject:key]) {
                    [sqlStr appendFormat:@"%@ ,",key];
                    [keys addObject:key];
                }
            }];
            [sqlStr deleteCharactersInRange:NSMakeRange(sqlStr.length - 1, 1)];
            
            [sqlStr appendFormat:@"FROM %@",tableName];

            NSMutableArray *values = [NSMutableArray arrayWithCapacity:0];
            if (where.count > 0) {
                [where enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                    [sqlStr appendFormat:@" %@",key];
                    [values addObjectsFromArray:obj];
                }];
            }
            
            //分页
//            NSInteger itemCount = [self itemCountForTable:tableName whereArr:whereArr];
//            for (int i = 0; i < itemCount; i += kMaxPageCount) {
//                @autoreleasepool {
//                    NSString *limit = [NSString stringWithFormat:@" LIMIT %@,%@",@(i),@(kMaxPageCount)];
//                    [sqlStr appendString:limit];
                    FMResultSet *rs = [db executeQuery:sqlStr withArgumentsInArray:values];
                    if (rs == nil) {
                        if (block) {
                            NSError *error = [self errorWithErrorCode:2003];
                            block(error);
                        }
                    }
                    while ([rs next]) {
                        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
                        [keys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                            if ([columnDict[obj] isEqualToString:SQL_TEXT]) {
                                NSString *value = [rs stringForColumn:obj];
                                if (value) [dic setObject:value forKey:obj];
                            } else if ([columnDict[obj] isEqualToString:SQL_INTEGER]){
                                [dic setObject:[NSNumber numberWithLongLong:[rs longLongIntForColumn:obj]] forKey:obj];
                            } else if ([columnDict[obj] isEqualToString:SQL_REAL]){
                                [dic setObject:[NSNumber numberWithDouble:[rs doubleForColumn:obj]] forKey:obj];
                            } else if ([columnDict[obj] isEqualToString:SQL_BLOB]){
                                NSData *data = [rs dataForColumn:obj];
                                if (data) [dic setObject:data forKey:obj];
                            }
                        }];
                        [dataArr addObject:dic];
                    }
                    [rs close];
//                }
//            }
        }
    }];
    return dataArr;
}

//查询整表
- (NSMutableArray *)queryAll:(NSString *)tableName callback:(void(^)(NSError *error))block{
    if (tableName == nil){
        if (block) {
            NSError *error = [self errorWithErrorCode:2000];
            block(error);
        }
        return nil;
    }

    NSMutableArray *dataArr = [NSMutableArray array];
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@",tableName];
        FMResultSet *rs = [db executeQuery:sql];
        if (rs == nil) {
            if (block) {
                NSError *error = [self errorWithErrorCode:2003];
                block(error);
            }
        }
        while ([rs next]) {
            int count = [rs columnCount];
            NSMutableDictionary *dic = [NSMutableDictionary dictionary];
            for (int i = 0 ; i < count ; i++) {
                NSString *key = [rs columnNameForIndex:i];
                id value = [rs objectForColumnIndex:i];
                [dic setValue:value forKey:key];
            }
            [dataArr addObject:dic];
        }
        [rs close];
    }];
    return dataArr;
}

//得到表所有字段名
- (NSArray *)tableColumnsArr:(NSString *)tableName db:(FMDatabase *)db{
    NSMutableArray *columns = [NSMutableArray arrayWithCapacity:0];//table中的字段名
    FMResultSet *resultSet = [db getTableSchema:tableName];
    while([resultSet next]){
        [columns addObject:[resultSet stringForColumn:@"name"]];//获得table中的字段名
    }
    [resultSet close];
    return columns;
}

- (dispatch_queue_t)queue{
    if (_queue == nil) {
        _queue = dispatch_queue_create("DataBaseConcurrent", DISPATCH_QUEUE_CONCURRENT);
    }
    return _queue;
}

- (FMDatabaseQueue *)dbQueue{
    return _dbQueue;
}

- (NSError *)errorWithErrorCode:(NSInteger)errorCode {
    NSString *errorMessage;
    
    switch (errorCode) {
        case 2000:
            errorMessage = @"传入参数有误";
            break;
        case 2001:
            errorMessage = @"该表不存在";
            break;
        case 2002:
            errorMessage = @"更新数据-警告：没有where子句";
            break;
        case 2003:
            errorMessage = @"查询错误";
            break;
        default:
            errorMessage = @"hxdb 未知出错";
            break;
    }
    return [NSError errorWithDomain:HXDBErrorDomain
                               code:errorCode
                           userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
}

@end
