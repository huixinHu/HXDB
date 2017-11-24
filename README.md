# HXDB
FMDB的简单封装
一些FMDB封装框架功能比较多，代码量也比较大，但是很多功能不常用，因而自行封装一个适用于手头项目的轻量级小框架。
因为项目需要在多线程下操作数据库，所以只基于FMDatabaseQueue进行了封装。

- FMDB简单二次封装
- 线程安全
- 支持事务操作
- 支持模型存储，但不支持集合类型、自定义类类型属性等等。（支持NSString、NSNumber、NSInteger 、BOOL、int、float、 double、NSData等简单类型属性）

1.数据库的创建
-----------
```objectivec
+ (instancetype)shareDB;

+ (instancetype)shareDB:(NSString *)dbName;

+ (instancetype)shareDB:(NSString *)dbName dbPath:(NSString *)dbpath;
```
三个单例方法，`dbName`为数据库名，参数如果为nil，那么就会创建一个名为`XiaoYa.sqlite`的数据库文件；如果  dbpath  为子路径名，若参数为nil，那么就默认在`NSDocumentDirectory`下创建数据库文件。如使用`shareDB `方法创建，则默认在NSDocumentDirectory下创建XiaoYa.sqlite。
使用这三个方法中任意一个创建数据库，之后再使用三个方法中任意一个都会会的同一个实例。

```objectivec
@property (nonatomic ,strong) HXDBManager *hxdb;

self.hxdb = [HXDBManager shareDB];
self.hxdb = [HXDBManager shareDB:@"HXDB.sqlite"];
//在hxDataBasePath/hxDataBasePath路径下创建HXDB.sqlite
self.hxdb = [HXDBManager shareDB:@"HXDB.sqlite" dbPath:@"hxDataBasePath"];
```

2.切换数据库
-----------
考虑到有用户退出登录、切换到另一个用户账号的情况，每一个用户需要单独一份数据，所以需要切换数据库。

```objectivec
- (void)changeFilePath:(NSString *)path dbName:(NSString *)dbName;
```
path参数是文件子路径，dbName是数据库名。

```objectivec
[self.hxdb changeFilePath:[Utils HXNSStringMD5:appDelegate.userid] dbName:@"XiaoYa.sqlite"];
```

3.创建表
-----------
方式1：根据sql语句创建表

```objectivec
/**
根据sql语句创建表

@param sql SQL语句
@param tableName 表名
@return 创建表是否成功
*/
- (BOOL)tableCreate:(NSString *)sql table:(NSString *)tableName;
```
```objectivec
[self.hxdb tableCreate:@"CREATE TABLE IF NOT EXISTS memberGroupRelation (memberId TEXT,groupId TEXT, FOREIGN KEY(groupId) REFERENCES groupTable(groupId) ON DELETE CASCADE);" table:@"memberGroupRelation"];
```

方式2：根据字典创建表
字典key：字段名，字典value：字段类型。可以指定主键字段名，如果不需要主键 pk 参数传入nil即可。

```objectivec
/**
根据字典创建表

@param tableName 表名
@param dict 字典，key 字段名、value 字段类型
@param pk 主键，可为nil
@return 是否成功
*/
- (BOOL)createTable:(NSString *)tableName colDict:(NSDictionary *)dict primaryKey:(NSString *)pk;
```
```objectivec
[self.hxdb createTable:groupTable colDict:@{@"groupId":@"TEXT",@"groupName":@"TEXT",@"groupAvatarId":@"TEXT",@"numberOfMember":@"TEXT",@"groupManagerId":@"TEXT",@"deleteFlag":@"INTEGER"} primaryKey:@"groupId"];
```

方式3：根据模型创建表，字段名就是对应模型的属性名

```objectivec
/**
根据模型类创建表

@param tableName 表名
@param cls 模型类
@param pk 主键，可为nil
@param colArr 模型中不需要作为表字段的属性
@return 创建表是否成功
*/
- (BOOL)createTable:(NSString *)tableName modelClass:(Class)cls primaryKey:(NSString *)pk excludeProperty:(NSArray *)colArr;
```

```objectivec
模型类：
@interface Person : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSNumber *phone;
@property (nonatomic, strong) NSData *userData;
@property (nonatomic, assign) NSInteger identity;
@property (nonatomic, assign) BOOL sex;
@property (nonatomic, assign) int age;
@property (nonatomic, assign) float height;  //可能会丢失精度
@property (nonatomic, assign) double weight;

@property (nonatomic, strong)NSDictionary *testDic;

@end

创建表：
[self.hxdb createTable:@"modelTable" modelClass:NSClassFromString(@"Person") primaryKey:@"identity" excludeProperty:nil];
```
要注意，NSDictionary这种集合类型的属性不会作为表字段，除此之外还有NSArray、NSSet等集合类型。

4.删除表
-----------
```objectivec
/**
删除表

@param tableName 表名
@param block 删除失败回调
*/
- (void)dropTable:(NSString *)tableName callback:(void(^)(NSError *error ))block;
```

```objectivec
[self.hxdb dropTable:@"modelTable" callback:^(NSError *error) {
	NSLog(@"error");
}];
```

5.0增删改数据
-----------
直接传入sql语句进行增删查改

```objectivec
/**
直接传入sql语句进行增删查改

@param sql SQL语句
@param block 回调
*/
- (void)updateWithSqlStat:(NSString *)sql callback:(void(^)(NSError *error ))block;
//批量版本
- (void)updateWithSqlStatInTransaction:(NSArray <NSString *> *)sqlArr callback:(void(^)(NSError *error))block;
```

5.1插入数据
-----------
1.插入单个模型

```objectivec
/**
插入单个模型

@param tableName 表名
@param model 模型对象
@param colArr 模型中不需要插入到表的属性名集合
@param block 回调
*/
- (void)insertTable:(NSString *)tableName model:(id)model excludeProperty:(NSArray *)colArr callback:(void(^)(NSError *error ))block;
```

```objectivec
Person *person = [[Person alloc] init];
person.name = @"PersonName";
person.phone = @(12345667890);
person.userData = [@"testData" dataUsingEncoding:NSUTF8StringEncoding];
person.identity = 60;
person.sex = 1;
person.age = 23;
person.height = 170.1;
person.weight = 233.33333;
person.testDic = [NSDictionary dictionary];
//插入一个模型对象的数据，其中weight和height属性不需要被插入
[self.hxdb insertTable:@"modelTable" model:person excludeProperty:@[@"height",@"weight"] callback:^(NSError *error) {
	NSLog(@"%@",error);
}];
```

2.批量插入模型

```objectivec
/**
批量插入模型

@param tableName 表名
@param modelArr 模型对象数组
@param colArr 一一对应模型对象数组中的每一元素，模型对象中不需要插入到表的属性名集合。需要程序员自行管理一一对应的关系，如果某模型对象没有要剔除的属性，则对应的excludeArr为空数组即可；如果所有模型对象都不需要剔除某些属性，则excludeProperty传入nil即可。
@param block （失败）回调
*/
- (void)insertTableInTransaction:(NSString *)tableName modelArr:(NSArray <id>*)modelArr excludeProperty:(NSArray <NSArray *>*)colArr callback:(void(^)(NSError *error ))block;
```

```objectivec
//一组数据
NSMutableArray *testModelArr = [NSMutableArray arrayWithCapacity:0];
//所有待插入模型对象中不需要插入到表的属性名集合
NSMutableArray *exclude = [NSMutableArray arrayWithCapacity:0];
for (int i = 0; i < 3; i++) {
Person *person = [[Person alloc] init];
person.name = @"PersonName";
person.phone = @(12345667890);
person.userData = [@"testData" dataUsingEncoding:NSUTF8StringEncoding];
person.identity = arc4random() % 1000;
person.sex = 1;
person.age = 23;
person.height = 170.1;
person.weight = 233.33333;
person.testDic = [NSDictionary dictionary];

[testModelArr addObject:person];

[exclude addObject:@[@"height",@"weight"]];
}
[self.hxdb insertTableInTransaction:@"modelTable" modelArr:testModelArr excludeProperty:exclude callback:^(NSError *error) {
	NSLog(@"%@",error);;
}];
```
关于`excludeProperty`：需要程序员自行管理一一对应的关系，如果某模型对象没有要剔除的属性，则对应的excludeArr为空数组即可，比如`[exclude addObject:@[]];`；如果所有模型对象都不需要剔除某些属性，则excludeProperty传入nil即可。

3.插入单条记录
 
```objectivec
/**
插入单条记录

@param tableName 表名
@param paraDict 待插入数据。字典key：字段名，value：字段值
@param block 回调
*/
- (void)insertTable:(NSString *)tableName param:(NSDictionary *)paraDict callback:(void(^)(NSError *error ))block;
```

```objectivec
NSDictionary *paraDict = @{@"name":@"commet",@"phone":@"13535230987",@"identity":@"999"};

[self.hxdb insertTable:@"modelTable" param:paraDict callback:^(NSError *error) {
	if(error) NSLog(@"插入表失败：%@",error);
}];
```

4.批量插入记录

```objectivec
/**
批量插入记录

@param tableName 表名
@param paraArr 待插入数据数组。数组每个元素是字典，字典构成同上。
@param block 回调
*/
- (void)insertTableInTransaction:(NSString *)tableName paramArr:(NSArray <NSDictionary *>*)paraArr callback:(void(^)(NSError *error))block;
```

5.2更新数据
-----------
1.更新指定模型数据

```objectivec
/**
更新单个模型

@param tableName 表名
@param model 模型对象
@param colArr 模型中不需要更新的属性名集合
@param where where子句字典。key:where子句遵循绑定语法，value：绑定值数组。比如“where name = 'John' AND age = '17'” -> @{@"WHERE name = ? AND age = ?":@[@"John",@"17"]}。要保证where字典有且仅有一组key-value
@param block 回调
*/
- (void)updateTable:(NSString *)tableName model:(id)model excludeProperty:(NSArray *)colArr whereDict:(NSDictionary *)where callback:(void(^)(NSError *error ))block;
```

根据模型对象更新数据，其中name、userData、identity、age属性不需要更新。如果where传入nil，则对每条记录都进行更新。

```objectivec
//根据模型对象更新数据，其中name、userData、identity、age属性不需要更新
[self.hxdb updateTable:@"modelTable" model:person excludeProperty:@[@"name",@"userData",@"identity",@"age"] whereDict:@{@"where identity = ?" : @[@60]} callback:^(NSError *error) {
	NSLog(@"%@",error);
}];
```

2.批量更新模型数据

```objectivec
/**
批量更新模型

@param tableName 表名
@param modelArr 模型对象集合
@param colArr 一一对应模型对象数组中的每一元素，模型对象中不需要更新的属性名集合
@param whereArr where子句字典的集合。where子句字典 -- key:where子句遵循绑定语法，value：绑定值数组。比如“where name = 'John' AND age = '17'” -> @{@"WHERE name = ? AND age = ?":@[@"John",@"17"]}。要保证where字典有且仅有一组key-value
@param block 回调
*/
- (void)updateTableInTransaction:(NSString *)tableName modelArr:(NSArray <id>*)modelArr excludeProperty:(NSArray <NSArray *>*)colArr whereArrs:(NSArray<NSDictionary *> *)whereArr callback:(void (^)(NSError *))block;
```
要注意此处where子句（字典）必须和模型一一对应且必须不能为空。由于这个方法是对同一个表进行批量更新，如果有其中一个没有where子句（就会更新整表），那么批量更新就没意义了

```objectivec
NSMutableArray *testModelArr = [NSMutableArray arrayWithCapacity:0];
NSMutableArray *exclude = [NSMutableArray arrayWithCapacity:0];
NSMutableArray *whereArr = [NSMutableArray arrayWithCapacity:0];
for (int i = 0; i < 3; i++) {
Person *person = [[Person alloc] init];
person.name = @"PersonName";
person.phone = @(11111111);
person.userData = [@"testData" dataUsingEncoding:NSUTF8StringEncoding];
person.identity = i+1;
person.sex = 0;
person.age = 24;
person.height = 170.1;
person.weight = 233.33333;
person.testDic = [NSDictionary dictionary];

[testModelArr addObject:person];

[exclude addObject:@[@"height",@"weight"]];
[whereArr addObject:@{@"where identity = ?" : @[[NSNumber numberWithInteger:person.identity]]}];
}

//批量更新模型
[self.hxdb updateTableInTransaction:@"modelTable" modelArr:testModelArr excludeProperty:exclude whereArrs:whereArr callback:^(NSError *error) {
	NSLog(@"%@",error);
}];
```

3.更新单个记录

```objectivec
/**
更新单个记录

@param tableName 表名
@param paraDict 待更新数据。字典key：字段名，value：字段值
@param where where子句字典。key:where子句遵循绑定语法，value：绑定值数组。比如“where name = 'John' AND age = '17'” -> @{@"WHERE name = ? AND age = ?":@[@"John",@"17"]}。要保证where字典有且仅有一组key-value
@param block 回调
*/
- (void)updateTable:(NSString *)tableName param:(NSDictionary *)paraDict whereDict:(NSDictionary *)where callback:(void(^)(NSError *error ))block;
```
```objectivec
//更新单个记录
NSDictionary *paraDict = @{@"name":@"commet",@"phone":@"13535230987"};

[self.hxdb updateTable:@"modelTable" param:paraDict whereDict:@{@"where identity = ?" : @[@1]} callback:^(NSError *error) {
	if(error) NSLog(@"%@",error);
}];
```

4.批量更新记录

```objectivec
/**
批量更新记录

@param tableName 表名
@param paraArr 待更新数据集合。数组每个元素是字典，字典构成同上
@param whereArr where子句字典的集合。where子句字典 -- key:where子句遵循绑定语法，value：绑定值数组。比如“where name = 'John' AND age = '17'” -> @{@"WHERE name = ? AND age = ?":@[@"John",@"17"]}。要保证where字典有且仅有一组key-value
@param block 回调
*/
- (void)updateTableInTransaction:(NSString *)tableName paramArr:(NSArray <NSDictionary *>*)paraArr whereArrs:(NSArray <NSDictionary *>*)whereArr callback:(void(^)(NSError *error))block;
```

5.3删除数据
-----------
1.删除指定数据

```objectivec
/**
删除单条件记录

@param tableName 表名
@param where where子句字典。key:where子句遵循绑定语法，value：绑定值数组。比如“where name = 'John' AND age = '17'” -> @{@"WHERE name = ? AND age = ?":@[@"John",@"17"]}。要保证where字典有且仅有一组key-value
@param block 回调
*/
- (void)deleteTable:(NSString *)tableName whereDict:(NSDictionary *)where callback:(void(^)(NSError *error))block;
```

如果where为空就删除整表数据

```objectivec
[self.hxdb deleteTable:@"modelTable" whereDict:@{@"where age = ?" : @[@24]} callback:^(NSError *error) {
	if(error) NSLog(@"%@",error);
}];
```

2.批量删除数据

```objectivec
/**
批量删除不同条件的记录

@param tableName 表名
@param whereArrs where子句字典的集合。where子句字典 -- key:where子句遵循绑定语法，value：绑定值数组。比如“where name = 'John' AND age = '17'” -> @{@"WHERE name = ? AND age = ?":@[@"John",@"17"]}。要保证where字典有且仅有一组key-value
@param block 回调
*/
- (void)deleteTableInTransaction:(NSString *)tableName whereArrs:(NSArray <NSDictionary *>*)whereArrs callback:(void(^)(NSError *error))block;
```

```objectivec
//批量删除
NSMutableArray *deleteWhere = [NSMutableArray array];
[deleteWhere addObject:@{@"where sex = ?" : @[@0]}];
[deleteWhere addObject:@{@"where sex = ? and name = ?":@[@1,@"commet"]}];
[deleteWhere addObject:@{@"where phone = ?" : @[@"305757732"]}];
[self.hxdb deleteTableInTransaction:@"modelTable" whereArrs:deleteWhere callback:^(NSError *error) {

}];
```

6.查询
-----------
1.根据条件查询有多少条记录

```objectivec
/**
根据条件查询有多少条记录

@param tableName 表名
@param where where子句字典。key:where子句遵循绑定语法，value：绑定值数组。比如“where name = 'John' AND age = '17'” -> @{@"WHERE name = ? AND age = ?":@[@"John",@"17"]}。要保证where字典有且仅有一组key-value
@return 记录数目
*/
- (int)itemCountForTable:(NSString *)tableName whereDict:(NSDictionary *)where;
```
```objectivec
int count = [self.hxdb itemCountForTable:@"modelTable" whereDict:@{@"where sex = ?" : @[@1]}];
NSLog(@"count = %d",count);
```

2.根据模型类查询

```objectivec
/**
根据条件查询模型

@param tableName 表名
@param cls 模型类
@param colArr 模型中不需要被查询的属性名集合
@param where where子句字典。key:where子句遵循绑定语法，value：绑定值数组。比如“where name = 'John' AND age = '17'” -> @{@"WHERE name = ? AND age = ?":@[@"John",@"17"]}。要保证where字典有且仅有一组key-value
@param block 回调
@return 查询结果
*/
- (NSMutableArray *)queryTable:(NSString *)tableName modelClass:(Class)cls excludeProperty:(NSArray *)colArr whereDict:(NSDictionary *)where callback:(void(^)(NSError *error))block;
```

```objectivec
NSMutableArray *rsArr = [self.hxdb queryTable:@"modelTable" modelClass:NSClassFromString(@"Person") excludeProperty:nil whereDict:nil callback:^(NSError *error) {

}];
NSLog(@"rs:%@",rsArr);
```

3.根据条件查询

```objectivec
/**
根据条件查询

@param tableName 表名
@param columnDict 查询字段。字典：key 字段名，value 字段对应的sql数据类型
@param where where子句字典。key:where子句遵循绑定语法，value：绑定值数组。比如“where name = 'John' AND age = '17'” -> @{@"WHERE name = ? AND age = ?":@[@"John",@"17"]}。要保证where字典有且仅有一组key-value
@param block 回调
@return 查询结果
*/
- (NSMutableArray *)queryTable:(NSString *)tableName columns:(NSDictionary *)columnDict whereDict:(NSDictionary *)where callback:(void(^)(NSError *error))block;
```

4.查询整表

```objectivec
/**
查询整表

@param tableName 表名
@param block 回调
@return 查询结果
*/
- (NSMutableArray *)queryAll:(NSString *)tableName callback:(void(^)(NSError *error))block;
```

其他
-----------
一般为了防止ui卡死，把数据库操作放在异步线程。比如：

```
dispatch_async(dispatch_get_global_queue(0, 0), ^{
NSMutableArray *rsArr = [self.hxdb queryTable:@"modelTable" modelClass:NSClassFromString(@"Person") excludeProperty:nil whereDict:nil callback:^(NSError *error) {

}];
	NSLog(@"rs:%@",rsArr);
});
```
