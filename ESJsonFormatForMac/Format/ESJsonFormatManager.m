//
//  ESJsonFormatManager.m
//  ESJsonFormat
//
//  Created by 尹桥印 on 15/6/28. Change by ZX on 17/5/17
//  Copyright (c) 2015年 EnjoySR. All rights reserved.
//

#import "ESJsonFormatManager.h"
#import "ESClassInfo.h"
#import "ESFormatInfo.h"
#import "ESClassInfo.h"
#import "ESPair.h"
#import "ESJsonFormat.h"
#import "ESJsonFormatSetting.h"
#import "ESPbxprojInfo.h"
#import "ESClassInfo.h"

const NSString * const kDictionaryContentCodeRowPrefix = @" \t\t\t";
const NSString * const kDictionaryContentCodeRowSuffix = @", \n";
@interface ESJsonFormatManager()

@end

@implementation ESJsonFormatManager

+ (NSString *)parsePropertyContentWithClassInfo:(ESClassInfo *)classInfo{
    NSMutableString *resultStr = [NSMutableString string];
    NSDictionary *dic = classInfo.classDic;
    [dic enumerateKeysAndObjectsUsingBlock:^(id key, NSObject *obj, BOOL *stop) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"isSwift"]) {
            [resultStr appendFormat:@"\n%@\n",[self formatSwiftWithKey:key value:obj classInfo:classInfo]];
        }else if([[NSUserDefaults standardUserDefaults] boolForKey:@"isTs"]){
            [resultStr appendFormat:@"\n%@\n",[self formatTSWithKey:key value:obj classInfo:classInfo]];
        }else{
            [resultStr appendFormat:@"\n%@\n",[self formatObjcWithKey:key value:obj classInfo:classInfo]];
        }
    }];
    return resultStr;
}

+ (NSString *)parsePropertyContentZWithClassInfo:(ESClassInfo *)classInfo{
    NSMutableString *resultStr = [NSMutableString stringWithFormat:@"\n    modelContainerPropertyGenericClass = function () {\n       return{"];
    NSDictionary *dic = classInfo.classDic;
    
    [dic enumerateKeysAndObjectsUsingBlock:^(id key, NSObject *obj, BOOL *stop) {
        if([[NSUserDefaults standardUserDefaults] boolForKey:@"isTs"]){
            if ([self formatTSForGCMWithKey:key value:obj classInfo:classInfo].length>0) {
                [resultStr appendFormat:@"\n%@",[self formatTSForGCMWithKey:key value:obj classInfo:classInfo]];
            }
        }
    }];
    [resultStr appendString:@"\n       }\n    }\n"];
    return resultStr;
}

/**
 *  格式化OC属性字符串
 *
 *  @param key       JSON里面key字段
 *  @param value     JSON里面key对应的NSDiction或者NSArray
 *  @param classInfo 类信息
 *
 *  @return
 */
+ (NSString *)formatObjcWithKey:(NSString *)key value:(NSObject *)value classInfo:(ESClassInfo *)classInfo{
    NSString *qualifierStr = @"copy";
    NSString *typeStr = @"NSString";
    //判断大小写
    if ([ESUppercaseKeyWords containsObject:key] && [ESJsonFormatSetting defaultSetting].uppercaseKeyWordForId) {
        key = [key uppercaseString];
    }
    if ([value isKindOfClass:[NSString class]]) {
        return [NSString stringWithFormat:@"@property (nonatomic, %@) %@ *%@;",qualifierStr,typeStr,key];
    }else if([value isKindOfClass:[@(YES) class]]){
        //the 'NSCFBoolean' is private subclass of 'NSNumber'
        qualifierStr = @"assign";
        typeStr = @"BOOL";
        return [NSString stringWithFormat:@"@property (nonatomic, %@) %@ %@;",qualifierStr,typeStr,key];
    }else if([value isKindOfClass:[NSNumber class]]){
        qualifierStr = @"assign";
        NSString *valueStr = [NSString stringWithFormat:@"%@",value];
        if ([valueStr rangeOfString:@"."].location!=NSNotFound){
            typeStr = @"CGFloat";
        }else{
            NSNumber *valueNumber = (NSNumber *)value;
            if ([valueNumber longValue]<2147483648) {
                typeStr = @"NSInteger";
            }else{
                typeStr = @"long long";
            }
        }
        return [NSString stringWithFormat:@"@property (nonatomic, %@) %@ %@;",qualifierStr,typeStr,key];
    }else if([value isKindOfClass:[NSArray class]]){
        NSArray *array = (NSArray *)value;
        
        //May be 'NSString'，will crash
        NSString *genericTypeStr = @"";
        NSObject *firstObj = [array firstObject];
        if ([firstObj isKindOfClass:[NSDictionary class]]) {
            ESClassInfo *childInfo = classInfo.propertyArrayDic[key];
            genericTypeStr = [NSString stringWithFormat:@"<%@ *>",childInfo.className];
        }else if ([firstObj isKindOfClass:[NSString class]]){
            genericTypeStr = @"<NSString *>";
        }else if ([firstObj isKindOfClass:[NSNumber class]]){
            genericTypeStr = @"<NSNumber *>";
        }
        
        qualifierStr = @"strong";
        typeStr = @"NSArray";
        if ([ESJsonFormatSetting defaultSetting].useGeneric && [ESUtils isXcode7AndLater]) {
            return [NSString stringWithFormat:@"@property (nonatomic, %@) %@%@ *%@;",qualifierStr,typeStr,genericTypeStr,key];
        }
        return [NSString stringWithFormat:@"@property (nonatomic, %@) %@ *%@;",qualifierStr,typeStr,key];
    }else if ([value isKindOfClass:[NSDictionary class]]){
        qualifierStr = @"strong";
        ESClassInfo *childInfo = classInfo.propertyClassDic[key];
        typeStr = childInfo.className;
        if (!typeStr) {
            typeStr = [key capitalizedString];
        }
        return [NSString stringWithFormat:@"@property (nonatomic, %@) %@ *%@;",qualifierStr,typeStr,key];
    }
    return [NSString stringWithFormat:@"@property (nonatomic, %@) %@ *%@;",qualifierStr,typeStr,key];
}


/**
 *  格式化Swift属性字符串
 *
 *  @param key       JSON里面key字段
 *  @param value     JSON里面key对应的NSDiction或者NSArray
 *  @param classInfo 类信息
 *
 *  @return
 */
+ (NSString *)formatSwiftWithKey:(NSString *)key value:(NSObject *)value classInfo:(ESClassInfo *)classInfo{
    NSString *typeStr = @"String?";
    //判断大小写
    if ([ESUppercaseKeyWords containsObject:key] && [ESJsonFormatSetting defaultSetting].uppercaseKeyWordForId) {
        key = [key uppercaseString];
    }
    if ([value isKindOfClass:[NSString class]]) {
        return [NSString stringWithFormat:@"    var %@: %@",key,typeStr];
    }else if([value isKindOfClass:[@(YES) class]]){
        typeStr = @"Bool";
        return [NSString stringWithFormat:@"    var %@: %@ = false",key,typeStr];
    }else if([value isKindOfClass:[NSNumber class]]){
        NSString *valueStr = [NSString stringWithFormat:@"%@",value];
        if ([valueStr rangeOfString:@"."].location!=NSNotFound){
            typeStr = @"Double";
        }else{
            typeStr = @"Int";
        }
        return [NSString stringWithFormat:@"    var %@: %@ = 0",key,typeStr];
    }else if([value isKindOfClass:[NSArray class]]){
        ESClassInfo *childInfo = classInfo.propertyArrayDic[key];
        NSString *type = childInfo.className;
        return [NSString stringWithFormat:@"    var %@: [%@]?",key,type==nil?@"String":type];
    }else if ([value isKindOfClass:[NSDictionary class]]){
        ESClassInfo *childInfo = classInfo.propertyClassDic[key];
        typeStr = childInfo.className;
        if (!typeStr) {
            typeStr = [key capitalizedString];
        }
        return [NSString stringWithFormat:@"    var %@: %@?",key,typeStr];
    }
    return [NSString stringWithFormat:@"    var %@: %@",key,typeStr];
}

/**
 *  格式化TS属性字符串
 *
 *  @param key       JSON里面key字段
 *  @param value     JSON里面key对应的NSDiction或者NSArray
 *  @param classInfo 类信息
 *
 *  @return
 */
+ (NSString *)formatTSWithKey:(NSString *)key value:(NSObject *)value classInfo:(ESClassInfo *)classInfo{
    NSString *typeStr = @"string";
    //判断大小写
    if ([ESUppercaseKeyWords containsObject:key] && [ESJsonFormatSetting defaultSetting].uppercaseKeyWordForId) {
        key = [key uppercaseString];
    }
    if ([value isKindOfClass:[NSString class]]) {
        return [NSString stringWithFormat:@"    %@: %@;",key,typeStr];
    }else if([value isKindOfClass:[@(YES) class]]){
        typeStr = @"boolean";
        return [NSString stringWithFormat:@"    %@: %@;",key,typeStr];
    }else if([value isKindOfClass:[NSNumber class]]){
        typeStr = @"number";
        return [NSString stringWithFormat:@"    %@: %@;",key,typeStr];
    }else if([value isKindOfClass:[NSArray class]]){
        ESClassInfo *childInfo = classInfo.propertyArrayDic[key];
        NSString *type = childInfo.className;
        return [NSString stringWithFormat:@"    %@: Array<%@>;",key,type==nil?@"any":type];
    }else if ([value isKindOfClass:[NSDictionary class]]){
        ESClassInfo *childInfo = classInfo.propertyClassDic[key];
        typeStr = childInfo.className;
        if (!typeStr) {
            typeStr = [key capitalizedString];
        }
        return [NSString stringWithFormat:@"    %@: %@;",key,typeStr];
    }
    return [NSString stringWithFormat:@"    %@: %@;",key,typeStr];
}


/**
 为了TS modelContainerPropertyGenericClass

 @param key       JSON里面key字段
 @param value     JSON里面key对应的NSDiction或者NSArray
 @param classInfo 类信息
 @return
 */
+ (NSString *)formatTSForGCMWithKey:(NSString *)key value:(NSObject *)value classInfo:(ESClassInfo *)classInfo{
    NSString *typeStr = @"";
    //判断大小写
    if ([ESUppercaseKeyWords containsObject:key] && [ESJsonFormatSetting defaultSetting].uppercaseKeyWordForId) {
        key = [key uppercaseString];
    }
    
    if([value isKindOfClass:[NSArray class]]){
        ESClassInfo *childInfo = classInfo.propertyArrayDic[key];
        NSString *type = childInfo.className;
        if (type==nil) return [NSString stringWithFormat:@""];
        return [NSString stringWithFormat:@"            '%@':%@,",key,type];
    }else if ([value isKindOfClass:[NSDictionary class]]){
        ESClassInfo *childInfo = classInfo.propertyClassDic[key];
        typeStr = childInfo.className;
        if (!typeStr) {
            typeStr = [key capitalizedString];
        }
        return [NSString stringWithFormat:@"            '%@':%@,",key,typeStr];
    }
    return [NSString stringWithFormat:@""];
}


+ (NSString *)parseClassHeaderContentWithClassInfo:(ESClassInfo *)classInfo{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"isSwift"]) {
        return [self parseClassContentForSwiftWithClassInfo:classInfo];
    }else if([[NSUserDefaults standardUserDefaults] boolForKey:@"isTs"]){
        return [self parseClassContentForTSWithClassInfo:classInfo];
    }else{
        return [self parseClassHeaderContentForOjbcWithClassInfo:classInfo];
    }
}

+ (NSString *)parseClassImpContentWithClassInfo:(ESClassInfo *)classInfo{
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"isSwift"]) {
        return @"";
    }
    
    NSMutableString *result = [NSMutableString stringWithString:@""];
    if ([ESJsonFormatSetting defaultSetting].impOjbClassInArray) {
        [result appendFormat:@"@implementation %@\n%@\n%@\n@end\n",classInfo.className,[self methodContentOfObjectClassInArrayWithClassInfo:classInfo],[self methodContentOfObjectIDInArrayWithClassInfo:classInfo]];
    }else{
        [result appendFormat:@"@implementation %@\n\n@end\n",classInfo.className];
    }
    
    if ([ESJsonFormatSetting defaultSetting].outputToFiles) {
        //headerStr
        NSMutableString *headerString = [NSMutableString stringWithString:[self dealHeaderStrWithClassInfo:classInfo type:@"m"]];
        //import
        [headerString appendString:[NSString stringWithFormat:@"#import \"%@.h\"\n",classInfo.className]];
        for (NSString *key in classInfo.propertyArrayDic) {
            ESClassInfo *childClassInfo = classInfo.propertyArrayDic[key];
            [headerString appendString:[NSString stringWithFormat:@"#import \"%@.h\"\n",childClassInfo.className]];
        }
        [headerString appendString:@"\n"];
        [result insertString:headerString atIndex:0];
    }
    return [result copy];
}

/**
 *  解析.h文件内容--Objc
 *
 *  @param classInfo 类信息
 *
 *  @return
 */
+ (NSString *)parseClassHeaderContentForOjbcWithClassInfo:(ESClassInfo *)classInfo{
    NSString *superClassString = [[NSUserDefaults standardUserDefaults] valueForKey:@"SuperClass"];
    NSMutableString *result = nil;
    if (superClassString&&superClassString.length>0) {
        result = [NSMutableString stringWithFormat:@"@interface %@ : %@\n",classInfo.className,superClassString];
    }else{
        result = [NSMutableString stringWithFormat:@"@interface %@ : NSObject\n",classInfo.className];
    }
    [result appendString:classInfo.propertyContent];
    [result appendString:@"\n@end"];
    
    if ([ESJsonFormatSetting defaultSetting].outputToFiles) {
        //headerStr
        NSMutableString *headerString = [NSMutableString stringWithString:[self dealHeaderStrWithClassInfo:classInfo type:@"h"]];
        //@class
        [headerString appendString:[NSString stringWithFormat:@"%@\n\n",classInfo.atClassContent]];
        [result insertString:headerString atIndex:0];
    }
    return [result copy];
}

/**
 *  解析.swift文件内容--Swift
 *
 *  @param classInfo 类信息
 *
 *  @return
 */
+ (NSString *)parseClassContentForSwiftWithClassInfo:(ESClassInfo *)classInfo{
    NSString *superClassString = [[NSUserDefaults standardUserDefaults] valueForKey:@"SuperClass"];
    NSMutableString *result = nil;
    if (superClassString&&superClassString.length>0) {
        result = [NSMutableString stringWithFormat:@"@interface %@ : %@\n",classInfo.className,superClassString];
    }else{
        result = [NSMutableString stringWithFormat:@"@interface %@ : NSObject\n",classInfo.className];
    }
    [result appendString:classInfo.propertyContent];
    [result appendString:@"\n}"];
    if ([ESJsonFormatSetting defaultSetting].outputToFiles) {
        [result insertString:@"import UIKit\n\n" atIndex:0];
        //headerStr
        NSMutableString *headerString = [NSMutableString stringWithString:[self dealHeaderStrWithClassInfo:classInfo type:@"swift"]];
        [result insertString:headerString atIndex:0];
    }
    return [result copy];
}

+ (NSString *)parseClassContentForTSWithClassInfo:(ESClassInfo *)classInfo{
    NSString *superClassString = [[NSUserDefaults standardUserDefaults] valueForKey:@"SuperClass"];
    NSMutableString *result = nil;
    if (superClassString&&superClassString.length>0) {
        result = [NSMutableString stringWithFormat:@"\n// @ts-ignore\nclass %@ extends %@{\n",classInfo.className,superClassString];
    }else{
        result = [NSMutableString stringWithFormat:@"\n// @ts-ignore\nclass %@ extends FCObject{\n",classInfo.className];
    }
    [result appendString:classInfo.propertyContent];
    //添加构建方方
    [result appendString:@"\n    constructor(data: object){\n        super(data);\n        if (!data) return;\n        // @ts-ignore\n        this.modelAddProperty.call(this, data);\n    }\n"];
    [result appendString:@"\n    modelCustomPropertyMapper = function () {\n       return{\n       }\n    }\n"];
    
    [result appendString:classInfo.classContentForZ];
    [result appendString:@"\n}"];
    if ([ESJsonFormatSetting defaultSetting].outputToFiles) {
//        [result insertString:@"import UIKit\n\n" atIndex:0];
//        //headerStr
//        NSMutableString *headerString = [NSMutableString stringWithString:[self dealHeaderStrWithClassInfo:classInfo type:@"swift"]];
//        [result insertString:headerString atIndex:0];
    }
    return [result copy];
}

/**
 *  生成 MJExtension 的集合中指定对象的方法
 *
 *  @param classInfo 指定类信息
 *
 *  @return
 */
+ (NSString *)methodContentOfObjectClassInArrayWithClassInfo:(ESClassInfo *)classInfo{

    if (classInfo.propertyArrayDic.count == 0) {
        return @"";
    }else{
        NSMutableString *result = [NSMutableString string];
        for (NSString *key in classInfo.propertyArrayDic) {
            ESClassInfo *childClassInfo = classInfo.propertyArrayDic[key];
            [result appendFormat:@"%@@\"%@\": [%@ class]%@", kDictionaryContentCodeRowPrefix,  key, childClassInfo.className, kDictionaryContentCodeRowSuffix];
        }
        
        BOOL isYYModel = [[NSUserDefaults standardUserDefaults] boolForKey:@"isYYModel"];
        NSString *methodStr = nil;
        if (isYYModel) {
            //append method content (modelContainerPropertyGenericClass) if YYModel
            methodStr = [NSString stringWithFormat:@"\n+ (NSDictionary <NSString *, Class> *)modelContainerPropertyGenericClass\n{\n    return @{\n%@%@};\n}\n", result, kDictionaryContentCodeRowPrefix];
        }else{
            // append method content (mj_objectClassInArray)
            methodStr = [NSString stringWithFormat:@"\n+ (NSDictionary <NSString *, Class> *)mj_objectClassInArray\n{\n    return @{\n%@%@};\n}\n", result, kDictionaryContentCodeRowPrefix];
        }
        
        return methodStr;
    }
}


+ (NSString *)methodContentOfObjectIDInArrayWithClassInfo:(ESClassInfo *)classInfo{

    NSMutableString *result = [NSMutableString string];
    NSDictionary *dic = classInfo.classDic;
    NSLog(@"%@", dic);
    [dic enumerateKeysAndObjectsUsingBlock:^(id key, NSObject *obj, BOOL *stop) {
        NSLog(@"key====%@",key);
        NSLog(@"obj====%@",obj);
        
        if ([ESUppercaseKeyWords containsObject:key] && [ESJsonFormatSetting defaultSetting].uppercaseKeyWordForId) {
           
            [result appendFormat:@"%@@\"%@\": @\"%@\"%@", kDictionaryContentCodeRowPrefix, [key uppercaseString], key, kDictionaryContentCodeRowSuffix];
        }
    }];

    if (result.length == 0) {
        return @"";
    }
    
    BOOL isYYModel = [[NSUserDefaults standardUserDefaults] boolForKey:@"isYYModel"];
    NSString *methodStr = nil;
    if (isYYModel) {
        methodStr = [NSString stringWithFormat:@"\n+ (NSDictionary <NSString *,NSString *> *)modelCustomPropertyMapper\n{\n    return @{\n%@%@};\n}\n", result, kDictionaryContentCodeRowPrefix];
    }else {
        methodStr = [NSString stringWithFormat:@"\n+ (NSDictionary <NSString *,NSString *> *)mj_replacedKeyFromPropertyName\n{\n    return @{\n%@%@};\n}\n", result, kDictionaryContentCodeRowPrefix];
    }

    return methodStr;

}

/**
 *  拼装模板信息
 *
 *  @param classInfo 类信息
 *  @param type      .h或者.m或者.swift
 *
 *  @return
 */
+ (NSString *)dealHeaderStrWithClassInfo:(ESClassInfo *)classInfo type:(NSString *)type{
    //模板文字
    NSString *templateFile = [ESJsonFormatPluginPath stringByAppendingPathComponent:@"Contents/Resources/DataModelsTemplate.txt"];
    NSString *templateString = [NSString stringWithContentsOfFile:templateFile encoding:NSUTF8StringEncoding error:nil];
    //替换模型名字
    templateString = [templateString stringByReplacingOccurrencesOfString:@"__MODELNAME__" withString:[NSString stringWithFormat:@"%@.%@",classInfo.className,type]];
    //替换用户名
    templateString = [templateString stringByReplacingOccurrencesOfString:@"__NAME__" withString:NSFullUserName()];
    //产品名
    NSString *productName = [ESPbxprojInfo shareInstance].productName;
    if (productName.length) {
        templateString = [templateString stringByReplacingOccurrencesOfString:@"__PRODUCTNAME__" withString:productName];
    }
    //组织名
    NSString *organizationName = [ESPbxprojInfo shareInstance].organizationName;
    if (organizationName.length) {
        templateString = [templateString stringByReplacingOccurrencesOfString:@"__ORGANIZATIONNAME__" withString:organizationName];
    }
    //时间
    templateString = [templateString stringByReplacingOccurrencesOfString:@"__DATE__" withString:[self dateStr]];
    
    if ([type isEqualToString:@"h"] || [type isEqualToString:@"switf"]) {
        NSMutableString *string = [NSMutableString stringWithString:templateString];
        if ([type isEqualToString:@"h"]) {
            [string appendString:@"#import <Foundation/Foundation.h>\n\n"];
            NSString *superClassString = [[NSUserDefaults standardUserDefaults] valueForKey:@"SuperClass"];
            if (superClassString&&superClassString.length>0) {
                [string appendString:[NSString stringWithFormat:@"#import \"%@.h\" \n\n",superClassString]];
            }
        }else{
            [string appendString:@"import UIKit\n\n"];
            NSString *superClassString = [[NSUserDefaults standardUserDefaults] valueForKey:@"SuperClass"];
            if (superClassString&&superClassString.length>0) {
                [string appendString:[NSString stringWithFormat:@"import %@ \n\n",superClassString]];
            }
        }
        templateString = [string copy];
    }
    return [templateString copy];
}

/**
 *  返回模板信息里面日期字符串
 *
 *  @return
 */
+ (NSString *)dateStr{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yy/MM/dd";
    return [formatter stringFromDate:[NSDate date]];
}


+ (void)createFileWithFolderPath:(NSString *)folderPath classInfo:(ESClassInfo *)classInfo{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"isSwift"]) {
        //创建.h文件
        [self createFileWithFileName:[folderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.h",classInfo.className]] content:classInfo.classContentForH];
        //创建.m文件
        [self createFileWithFileName:[folderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.m",classInfo.className]] content:classInfo.classContentForM];
    }else{
        //创建.swift文件
        [self createFileWithFileName:[folderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.swift",classInfo.className]] content:classInfo.classContentForH];
    }
}

/**
 *  创建文件
 *
 *  @param FileName 文件名字
 *  @param content  文件内容
 */
+ (void)createFileWithFileName:(NSString *)FileName content:(NSString *)content{
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createFileAtPath:FileName contents:[content dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
}

@end
