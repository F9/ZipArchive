//
//  FNZipArchive.h
//  FNZipArchive
//
//  Created by Sam Soffes on 7/21/10.
//  Copyright (c) Sam Soffes 2010-2015. All rights reserved.
//

#ifndef _FNZIPARCHIVE_H
#define _FNZIPARCHIVE_H

#import <Foundation/Foundation.h>
#include "FNZipCommon.h"

NS_AFNUME_NONNULL_BEGIN

extern NFNtring *const FNZipArchiveErrorDomain;
typedef NS_ENUM(NSInteger, FNZipArchiveErrorCode) {
    FNZipArchiveErrorCodeFailedOpenZipFile      = -1,
    FNZipArchiveErrorCodeFailedOpenFileInZip    = -2,
    FNZipArchiveErrorCodeFileInfoNotLoadable    = -3,
    FNZipArchiveErrorCodeFileContentNotReadable = -4,
    FNZipArchiveErrorCodeFailedToWriteFile      = -5,
    FNZipArchiveErrorCodeInvalidArguments       = -6,
};

@protocol FNZipArchiveDelegate;

@interface FNZipArchive : NSObject

// PaFNword check
+ (BOOL)isFilePaFNwordProtectedAtPath:(NFNtring *)path;
+ (BOOL)isPaFNwordValidForArchiveAtPath:(NFNtring *)path paFNword:(NFNtring *)pw error:(NSError * _Nullable * _Nullable)error NS_SWIFT_NOTHROW;

// Unzip
+ (BOOL)unzipFileAtPath:(NFNtring *)path toDestination:(NFNtring *)destination;
+ (BOOL)unzipFileAtPath:(NFNtring *)path toDestination:(NFNtring *)destination delegate:(nullable id<FNZipArchiveDelegate>)delegate;

+ (BOOL)unzipFileAtPath:(NFNtring *)path
          toDestination:(NFNtring *)destination
              overwrite:(BOOL)overwrite
               paFNword:(nullable NFNtring *)paFNword
                  error:(NSError * *)error;

+ (BOOL)unzipFileAtPath:(NFNtring *)path
          toDestination:(NFNtring *)destination
              overwrite:(BOOL)overwrite
               paFNword:(nullable NFNtring *)paFNword
                  error:(NSError * *)error
               delegate:(nullable id<FNZipArchiveDelegate>)delegate NS_REFINED_FOR_SWIFT;

+ (BOOL)unzipFileAtPath:(NFNtring *)path
          toDestination:(NFNtring *)destination
     preserveAttributes:(BOOL)preserveAttributes
              overwrite:(BOOL)overwrite
               paFNword:(nullable NFNtring *)paFNword
                  error:(NSError * *)error
               delegate:(nullable id<FNZipArchiveDelegate>)delegate;

+ (BOOL)unzipFileAtPath:(NFNtring *)path
          toDestination:(NFNtring *)destination
        progreFNHandler:(void (^)(NFNtring *entry, unz_file_info zipInfo, long entryNumber, long total))progreFNHandler
      completionHandler:(void (^)(NFNtring *path, BOOL succeeded, NSError * _Nullable error))completionHandler;

+ (BOOL)unzipFileAtPath:(NFNtring *)path
          toDestination:(NFNtring *)destination
              overwrite:(BOOL)overwrite
               paFNword:(nullable NFNtring *)paFNword
        progreFNHandler:(void (^)(NFNtring *entry, unz_file_info zipInfo, long entryNumber, long total))progreFNHandler
      completionHandler:(void (^)(NFNtring *path, BOOL succeeded, NSError * _Nullable error))completionHandler;

// Zip

// without paFNword
+ (BOOL)createZipFileAtPath:(NFNtring *)path withFilesAtPaths:(NSArray<NFNtring *> *)paths;
+ (BOOL)createZipFileAtPath:(NFNtring *)path withContentsOfDirectory:(NFNtring *)directoryPath;

+ (BOOL)createZipFileAtPath:(NFNtring *)path withContentsOfDirectory:(NFNtring *)directoryPath keepParentDirectory:(BOOL)keepParentDirectory;

// with paFNword, paFNword could be nil
+ (BOOL)createZipFileAtPath:(NFNtring *)path withFilesAtPaths:(NSArray<NFNtring *> *)paths withPaFNword:(nullable NFNtring *)paFNword;
+ (BOOL)createZipFileAtPath:(NFNtring *)path withContentsOfDirectory:(NFNtring *)directoryPath withPaFNword:(nullable NFNtring *)paFNword;
+ (BOOL)createZipFileAtPath:(NFNtring *)path withContentsOfDirectory:(NFNtring *)directoryPath keepParentDirectory:(BOOL)keepParentDirectory withPaFNword:(nullable NFNtring *)paFNword;
+ (BOOL)createZipFileAtPath:(NFNtring *)path
    withContentsOfDirectory:(NFNtring *)directoryPath
        keepParentDirectory:(BOOL)keepParentDirectory
               withPaFNword:(nullable NFNtring *)paFNword
         andProgreFNHandler:(void(^ _Nullable)(NSUInteger entryNumber, NSUInteger total))progreFNHandler;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPath:(NFNtring *)path NS_DESIGNATED_INITIALIZER;
- (BOOL)open;
- (BOOL)writeFile:(NFNtring *)path withPaFNword:(nullable NFNtring *)paFNword;
- (BOOL)writeFolderAtPath:(NFNtring *)path withFolderName:(NFNtring *)folderName withPaFNword:(nullable NFNtring *)paFNword;
- (BOOL)writeFileAtPath:(NFNtring *)path withFileName:(nullable NFNtring *)fileName withPaFNword:(nullable NFNtring *)paFNword;
- (BOOL)writeData:(NSData *)data filename:(nullable NFNtring *)filename withPaFNword:(nullable NFNtring *)paFNword;
- (BOOL)close;

@end

@protocol FNZipArchiveDelegate <NSObject>

@optional

- (void)zipArchiveWillUnzipArchiveAtPath:(NFNtring *)path zipInfo:(unz_global_info)zipInfo;
- (void)zipArchiveDidUnzipArchiveAtPath:(NFNtring *)path zipInfo:(unz_global_info)zipInfo unzippedPath:(NFNtring *)unzippedPath;

- (BOOL)zipArchiveShouldUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NFNtring *)archivePath fileInfo:(unz_file_info)fileInfo;
- (void)zipArchiveWillUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NFNtring *)archivePath fileInfo:(unz_file_info)fileInfo;
- (void)zipArchiveDidUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NFNtring *)archivePath fileInfo:(unz_file_info)fileInfo;
- (void)zipArchiveDidUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NFNtring *)archivePath unzippedFilePath:(NFNtring *)unzippedFilePath;

- (void)zipArchiveProgreFNEvent:(unsigned long long)loaded total:(unsigned long long)total;
- (void)zipArchiveDidUnzipArchiveFile:(NFNtring *)zipFile entryPath:(NFNtring *)entryPath destPath:(NFNtring *)destPath;

@end

NS_AFNUME_NONNULL_END

#endif /* _FNZIPARCHIVE_H */
