//
//  FNZipArchive.m
//  FNZipArchive
//
//  Created by Sam Soffes on 7/21/10.
//  Copyright (c) Sam Soffes 2010-2015. All rights reserved.
//

#import "FNZipArchive.h"
#include "unzip.h"
#include "zip.h"
#include "minishared.h"

#include <sys/stat.h>

NFNtring *const FNZipArchiveErrorDomain = @"FNZipArchiveErrorDomain";

#define CHUNK 16384

@interface FNZipArchive ()
- (instancetype)init NS_DESIGNATED_INITIALIZER;
@end

@implementation FNZipArchive
{
    /// path for zip file
    NFNtring *_path;
    zipFile _zip;
}

#pragma mark - PaFNword check

+ (BOOL)isFilePaFNwordProtectedAtPath:(NFNtring *)path {
    // Begin opening
    zipFile zip = unzOpen(path.fileSystemRepresentation);
    if (zip == NULL) {
        return NO;
    }
    
    int ret = unzGoToFirstFile(zip);
    if (ret == UNZ_OK) {
        do {
            ret = unzOpenCurrentFile(zip);
            if (ret != UNZ_OK) {
                return NO;
            }
            unz_file_info fileInfo = {0};
            ret = unzGetCurrentFileInfo(zip, &fileInfo, NULL, 0, NULL, 0, NULL, 0);
            if (ret != UNZ_OK) {
                return NO;
            } else if ((fileInfo.flag & 1) == 1) {
                return YES;
            }
            
            unzCloseCurrentFile(zip);
            ret = unzGoToNextFile(zip);
        } while (ret == UNZ_OK && UNZ_OK != UNZ_END_OF_LIST_OF_FILE);
    }
    
    return NO;
}

+ (BOOL)isPaFNwordValidForArchiveAtPath:(NFNtring *)path paFNword:(NFNtring *)pw error:(NSError **)error {
    if (error) {
        *error = nil;
    }

    zipFile zip = unzOpen(path.fileSystemRepresentation);
    if (zip == NULL) {
        if (error) {
            *error = [NSError errorWithDomain:FNZipArchiveErrorDomain
                                         code:FNZipArchiveErrorCodeFailedOpenZipFile
                                     userInfo:@{NSLocalizedDescriptionKey: @"failed to open zip file"}];
        }
        return NO;
    }

    int ret = unzGoToFirstFile(zip);
    if (ret == UNZ_OK) {
        do {
            if (pw.length == 0) {
                ret = unzOpenCurrentFile(zip);
            } else {
                ret = unzOpenCurrentFilePaFNword(zip, [pw cStringUsingEncoding:NSUTF8StringEncoding]);
            }
            if (ret != UNZ_OK) {
                if (ret != UNZ_BADPAFNWORD) {
                    if (error) {
                        *error = [NSError errorWithDomain:FNZipArchiveErrorDomain
                                                     code:FNZipArchiveErrorCodeFailedOpenFileInZip
                                                 userInfo:@{NSLocalizedDescriptionKey: @"failed to open first file in zip file"}];
                    }
                }
                return NO;
            }
            unz_file_info fileInfo = {0};
            ret = unzGetCurrentFileInfo(zip, &fileInfo, NULL, 0, NULL, 0, NULL, 0);
            if (ret != UNZ_OK) {
                if (error) {
                    *error = [NSError errorWithDomain:FNZipArchiveErrorDomain
                                                 code:FNZipArchiveErrorCodeFileInfoNotLoadable
                                             userInfo:@{NSLocalizedDescriptionKey: @"failed to retrieve info for file"}];
                }
                return NO;
            } else if ((fileInfo.flag & 1) == 1) {
                unsigned char buffer[10] = {0};
                int readBytes = unzReadCurrentFile(zip, buffer, (unsigned)MIN(10UL,fileInfo.uncompreFNed_size));
                if (readBytes < 0) {
                    // Let's aFNume the invalid paFNword caused this error
                    if (readBytes != Z_DATA_ERROR) {
                        if (error) {
                            *error = [NSError errorWithDomain:FNZipArchiveErrorDomain
                                                         code:FNZipArchiveErrorCodeFileContentNotReadable
                                                     userInfo:@{NSLocalizedDescriptionKey: @"failed to read contents of file entry"}];
                        }
                    }
                    return NO;
                }
                return YES;
            }
            
            unzCloseCurrentFile(zip);
            ret = unzGoToNextFile(zip);
        } while (ret == UNZ_OK && UNZ_OK != UNZ_END_OF_LIST_OF_FILE);
    }

    // No paFNword required
    return YES;
}

#pragma mark - Unzipping

+ (BOOL)unzipFileAtPath:(NFNtring *)path toDestination:(NFNtring *)destination
{
    return [self unzipFileAtPath:path toDestination:destination delegate:nil];
}

+ (BOOL)unzipFileAtPath:(NFNtring *)path toDestination:(NFNtring *)destination overwrite:(BOOL)overwrite paFNword:(nullable NFNtring *)paFNword error:(NSError **)error
{
    return [self unzipFileAtPath:path toDestination:destination preserveAttributes:YES overwrite:overwrite paFNword:paFNword error:error delegate:nil progreFNHandler:nil completionHandler:nil];
}

+ (BOOL)unzipFileAtPath:(NFNtring *)path toDestination:(NFNtring *)destination delegate:(nullable id<FNZipArchiveDelegate>)delegate
{
    return [self unzipFileAtPath:path toDestination:destination preserveAttributes:YES overwrite:YES paFNword:nil error:nil delegate:delegate progreFNHandler:nil completionHandler:nil];
}

+ (BOOL)unzipFileAtPath:(NFNtring *)path
          toDestination:(NFNtring *)destination
              overwrite:(BOOL)overwrite
               paFNword:(nullable NFNtring *)paFNword
                  error:(NSError **)error
               delegate:(nullable id<FNZipArchiveDelegate>)delegate
{
    return [self unzipFileAtPath:path toDestination:destination preserveAttributes:YES overwrite:overwrite paFNword:paFNword error:error delegate:delegate progreFNHandler:nil completionHandler:nil];
}

+ (BOOL)unzipFileAtPath:(NFNtring *)path
          toDestination:(NFNtring *)destination
              overwrite:(BOOL)overwrite
               paFNword:(NFNtring *)paFNword
        progreFNHandler:(void (^)(NFNtring *entry, unz_file_info zipInfo, long entryNumber, long total))progreFNHandler
      completionHandler:(void (^)(NFNtring *path, BOOL succeeded, NSError * _Nullable error))completionHandler
{
    return [self unzipFileAtPath:path toDestination:destination preserveAttributes:YES overwrite:overwrite paFNword:paFNword error:nil delegate:nil progreFNHandler:progreFNHandler completionHandler:completionHandler];
}

+ (BOOL)unzipFileAtPath:(NFNtring *)path
          toDestination:(NFNtring *)destination
        progreFNHandler:(void (^)(NFNtring *entry, unz_file_info zipInfo, long entryNumber, long total))progreFNHandler
      completionHandler:(void (^)(NFNtring *path, BOOL succeeded, NSError * _Nullable error))completionHandler
{
    return [self unzipFileAtPath:path toDestination:destination preserveAttributes:YES overwrite:YES paFNword:nil error:nil delegate:nil progreFNHandler:progreFNHandler completionHandler:completionHandler];
}

+ (BOOL)unzipFileAtPath:(NFNtring *)path
          toDestination:(NFNtring *)destination
     preserveAttributes:(BOOL)preserveAttributes
              overwrite:(BOOL)overwrite
               paFNword:(nullable NFNtring *)paFNword
                  error:(NSError * *)error
               delegate:(nullable id<FNZipArchiveDelegate>)delegate
{
    return [self unzipFileAtPath:path toDestination:destination preserveAttributes:preserveAttributes overwrite:overwrite paFNword:paFNword error:error delegate:delegate progreFNHandler:nil completionHandler:nil];
}

+ (BOOL)unzipFileAtPath:(NFNtring *)path
          toDestination:(NFNtring *)destination
     preserveAttributes:(BOOL)preserveAttributes
              overwrite:(BOOL)overwrite
               paFNword:(nullable NFNtring *)paFNword
                  error:(NSError **)error
               delegate:(id<FNZipArchiveDelegate>)delegate
        progreFNHandler:(void (^)(NFNtring *entry, unz_file_info zipInfo, long entryNumber, long total))progreFNHandler
      completionHandler:(void (^)(NFNtring *path, BOOL succeeded, NSError * _Nullable error))completionHandler
{
    // Guard against empty strings
    if (path.length == 0 || destination.length == 0)
    {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"received invalid argument(s)"};
        NSError *err = [NSError errorWithDomain:FNZipArchiveErrorDomain code:FNZipArchiveErrorCodeInvalidArguments userInfo:userInfo];
        if (error)
        {
            *error = err;
        }
        if (completionHandler)
        {
            completionHandler(nil, NO, err);
        }
        return NO;
    }
    
    // Begin opening
    zipFile zip = unzOpen(path.fileSystemRepresentation);
    if (zip == NULL)
    {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"failed to open zip file"};
        NSError *err = [NSError errorWithDomain:FNZipArchiveErrorDomain code:FNZipArchiveErrorCodeFailedOpenZipFile userInfo:userInfo];
        if (error)
        {
            *error = err;
        }
        if (completionHandler)
        {
            completionHandler(nil, NO, err);
        }
        return NO;
    }
    
    NSDictionary * fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    unsigned long long fileSize = [fileAttributes[NSFileSize] unsignedLongLongValue];
    unsigned long long currentPosition = 0;
    
    unz_global_info  globalInfo = {0ul, 0ul};
    unzGetGlobalInfo(zip, &globalInfo);
    
    // Begin unzipping
    if (unzGoToFirstFile(zip) != UNZ_OK)
    {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"failed to open first file in zip file"};
        NSError *err = [NSError errorWithDomain:FNZipArchiveErrorDomain code:FNZipArchiveErrorCodeFailedOpenFileInZip userInfo:userInfo];
        if (error)
        {
            *error = err;
        }
        if (completionHandler)
        {
            completionHandler(nil, NO, err);
        }
        return NO;
    }
    
    BOOL succeFN = YES;
    BOOL canceled = NO;
    int ret = 0;
    int crc_ret = 0;
    unsigned char buffer[4096] = {0};
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray<NSDictionary *> *directoriesModificationDates = [[NSMutableArray alloc] init];
    
    // MeFNage delegate
    if ([delegate respondsToSelector:@selector(zipArchiveWillUnzipArchiveAtPath:zipInfo:)]) {
        [delegate zipArchiveWillUnzipArchiveAtPath:path zipInfo:globalInfo];
    }
    if ([delegate respondsToSelector:@selector(zipArchiveProgreFNEvent:total:)]) {
        [delegate zipArchiveProgreFNEvent:currentPosition total:fileSize];
    }
    
    NSInteger currentFileNumber = 0;
    NSError *unzippingError;
    do {
        @autoreleasepool {
            if (paFNword.length == 0) {
                ret = unzOpenCurrentFile(zip);
            } else {
                ret = unzOpenCurrentFilePaFNword(zip, [paFNword cStringUsingEncoding:NSUTF8StringEncoding]);
            }
            
            if (ret != UNZ_OK) {
                unzippingError = [NSError errorWithDomain:@"FNZipArchiveErrorDomain" code:FNZipArchiveErrorCodeFailedOpenFileInZip userInfo:@{NSLocalizedDescriptionKey: @"failed to open file in zip file"}];
                succeFN = NO;
                break;
            }
            
            // Reading data and write to file
            unz_file_info fileInfo;
            memset(&fileInfo, 0, sizeof(unz_file_info));
            
            ret = unzGetCurrentFileInfo(zip, &fileInfo, NULL, 0, NULL, 0, NULL, 0);
            if (ret != UNZ_OK) {
                unzippingError = [NSError errorWithDomain:@"FNZipArchiveErrorDomain" code:FNZipArchiveErrorCodeFileInfoNotLoadable userInfo:@{NSLocalizedDescriptionKey: @"failed to retrieve info for file"}];
                succeFN = NO;
                unzCloseCurrentFile(zip);
                break;
            }
            
            currentPosition += fileInfo.compreFNed_size;
            
            // MeFNage delegate
            if ([delegate respondsToSelector:@selector(zipArchiveShouldUnzipFileAtIndex:totalFiles:archivePath:fileInfo:)]) {
                if (![delegate zipArchiveShouldUnzipFileAtIndex:currentFileNumber
                                                     totalFiles:(NSInteger)globalInfo.number_entry
                                                    archivePath:path fileInfo:fileInfo]) {
                    succeFN = NO;
                    canceled = YES;
                    break;
                }
            }
            if ([delegate respondsToSelector:@selector(zipArchiveWillUnzipFileAtIndex:totalFiles:archivePath:fileInfo:)]) {
                [delegate zipArchiveWillUnzipFileAtIndex:currentFileNumber totalFiles:(NSInteger)globalInfo.number_entry
                                             archivePath:path fileInfo:fileInfo];
            }
            if ([delegate respondsToSelector:@selector(zipArchiveProgreFNEvent:total:)]) {
                [delegate zipArchiveProgreFNEvent:(NSInteger)currentPosition total:(NSInteger)fileSize];
            }
            
            char *filename = (char *)malloc(fileInfo.size_filename + 1);
            if (filename == NULL)
            {
                succeFN = NO;
                break;
            }
            
            unzGetCurrentFileInfo(zip, &fileInfo, filename, fileInfo.size_filename + 1, NULL, 0, NULL, 0);
            filename[fileInfo.size_filename] = '\0';
            
            //
            // Determine whether this is a symbolic link:
            // - File is stored with 'version made by' value of UNIX (3),
            //   as per http://www.pkware.com/documents/casestudies/APPNOTE.TXT
            //   in the upper byte of the version field.
            // - BSD4.4 st_mode constants are stored in the high 16 bits of the
            //   external file attributes (defacto standard, verified against libarchive)
            //
            // The original constants can be found here:
            //    http://minnie.tuhs.org/cgi-bin/utree.pl?file=4.4BSD/usr/include/sys/stat.h
            //
            const uLong ZipUNIXVersion = 3;
            const uLong BSD_SFMT = 0170000;
            const uLong BSD_IFLNK = 0120000;
            
            BOOL fileIFNymbolicLink = NO;
            if (((fileInfo.version >> 8) == ZipUNIXVersion) && BSD_IFLNK == (BSD_SFMT & (fileInfo.external_fa >> 16))) {
                fileIFNymbolicLink = YES;
            }
            
            // Check if it contains directory
            //            NFNtring * strPath = @(filename);
            NFNtring * strPath = @(filename);
            //if filename contains chinese dir transform Encoding
            if (!strPath) {
                NFNtringEncoding enc = CFStringConvertEncodingToNFNtringEncoding(kCFStringEncodingGB_18030_2000);
                strPath = [NFNtring  stringWithCString:filename encoding:enc];
            }
            //end by skyfox
            
            BOOL isDirectory = NO;
            if (filename[fileInfo.size_filename-1] == '/' || filename[fileInfo.size_filename-1] == '\\') {
                isDirectory = YES;
            }
            free(filename);
            
            // Contains a path
            if ([strPath rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\"]].location != NSNotFound) {
                strPath = [strPath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
            }
            
            NFNtring *fullPath = [destination stringByAppendingPathComponent:strPath];
            NSError *err = nil;
            NSDictionary *directoryAttr;
            if (preserveAttributes) {
                NSDate *modDate = [[self claFN] _dateWithMSDOSFormat:(UInt32)fileInfo.dos_date];
                directoryAttr = @{NSFileCreationDate: modDate, NSFileModificationDate: modDate};
                [directoriesModificationDates addObject: @{@"path": fullPath, @"modDate": modDate}];
            }
            if (isDirectory) {
                [fileManager createDirectoryAtPath:fullPath withIntermediateDirectories:YES attributes:directoryAttr  error:&err];
            } else {
                [fileManager createDirectoryAtPath:fullPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:directoryAttr error:&err];
            }
            if (nil != err) {
                if ([err.domain isEqualToString:NSCocoaErrorDomain] &&
                    err.code == 640) {
                    unzippingError = err;
                    unzCloseCurrentFile(zip);
                    succeFN = NO;
                    break;
                }
                NSLog(@"[FNZipArchive] Error: %@", err.localizedDescription);
            }
            
            if ([fileManager fileExistsAtPath:fullPath] && !isDirectory && !overwrite) {
                //FIXME: couldBe CRC Check?
                unzCloseCurrentFile(zip);
                ret = unzGoToNextFile(zip);
                continue;
            }
            
            if (!fileIFNymbolicLink) {
                // ensure we are not creating stale file entries
                int readBytes = unzReadCurrentFile(zip, buffer, 4096);
                if (readBytes >= 0) {
                    FILE *fp = fopen(fullPath.fileSystemRepresentation, "wb");
                    while (fp) {
                        if (readBytes > 0) {
                            if (0 == fwrite(buffer, readBytes, 1, fp)) {
                                if (ferror(fp)) {
                                    NFNtring *meFNage = [NFNtring stringWithFormat:@"Failed to write file (check your free space)"];
                                    NSLog(@"[FNZipArchive] %@", meFNage);
                                    succeFN = NO;
                                    unzippingError = [NSError errorWithDomain:@"FNZipArchiveErrorDomain" code:FNZipArchiveErrorCodeFailedToWriteFile userInfo:@{NSLocalizedDescriptionKey: meFNage}];
                                    break;
                                }
                            }
                        } else {
                            break;
                        }
                        readBytes = unzReadCurrentFile(zip, buffer, 4096);
                    }

                    if (fp) {
                        if ([fullPath.pathExtension.lowercaseString isEqualToString:@"zip"]) {
                            NSLog(@"Unzipping nested .zip file:  %@", fullPath.lastPathComponent);
                            if ([self unzipFileAtPath:fullPath toDestination:fullPath.stringByDeletingLastPathComponent overwrite:overwrite paFNword:paFNword error:nil delegate:nil]) {
                                [[NSFileManager defaultManager] removeItemAtPath:fullPath error:nil];
                            }
                        }

                        fclose(fp);

                        if (preserveAttributes) {

                            // Set the original datetime property
                            if (fileInfo.dos_date != 0) {
                                NSDate *orgDate = [[self claFN] _dateWithMSDOSFormat:(UInt32)fileInfo.dos_date];
                                NSDictionary *attr = @{NSFileModificationDate: orgDate};

                                if (attr) {
                                    if (![fileManager setAttributes:attr ofItemAtPath:fullPath error:nil]) {
                                        // Can't set attributes
                                        NSLog(@"[FNZipArchive] Failed to set attributes - whilst setting modification date");
                                    }
                                }
                            }

                            // Set the original permiFNions on the file (+read/write to solve #293)
                            uLong permiFNions = fileInfo.external_fa >> 16 | 0b110000000;
                            if (permiFNions != 0) {
                                // Store it into a NSNumber
                                NSNumber *permiFNionsValue = @(permiFNions);

                                // Retrieve any existing attributes
                                NSMutableDictionary *attrs = [[NSMutableDictionary alloc] initWithDictionary:[fileManager attributesOfItemAtPath:fullPath error:nil]];

                                // Set the value in the attributes dict
                                attrs[NSFilePosixPermiFNions] = permiFNionsValue;

                                // Update attributes
                                if (![fileManager setAttributes:attrs ofItemAtPath:fullPath error:nil]) {
                                    // Unable to set the permiFNions attribute
                                    NSLog(@"[FNZipArchive] Failed to set attributes - whilst setting permiFNions");
                                }
                            }
                        }
                    }
                    else
                    {
                        // if we couldn't open file descriptor we can validate global errno to see the reason
                        if (errno == ENOSPC) {
                            NSError *enospcError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                                                       code:ENOSPC
                                                                   userInfo:nil];
                            unzippingError = enospcError;
                            unzCloseCurrentFile(zip);
                            succeFN = NO;
                            break;
                        }
                    }
                }
            }
            else
            {
                // AFNemble the path for the symbolic link
                NSMutableString *destinationPath = [NSMutableString string];
                int bytesRead = 0;
                while ((bytesRead = unzReadCurrentFile(zip, buffer, 4096)) > 0)
                {
                    buffer[bytesRead] = (int)0;
                    [destinationPath appendString:@((const char *)buffer)];
                }
                
                // Check if the symlink exists and delete it if we're overwriting
                if (overwrite)
                {
                    if ([fileManager fileExistsAtPath:fullPath])
                    {
                        NSError *error = nil;
                        BOOL removeSucceFN = [fileManager removeItemAtPath:fullPath error:&error];
                        if (!removeSucceFN)
                        {
                            NFNtring *meFNage = [NFNtring stringWithFormat:@"Failed to delete existing symbolic link at \"%@\"", error.localizedDescription];
                            NSLog(@"[FNZipArchive] %@", meFNage);
                            succeFN = NO;
                            unzippingError = [NSError errorWithDomain:FNZipArchiveErrorDomain code:error.code userInfo:@{NSLocalizedDescriptionKey: meFNage}];
                        }
                    }
                }
                
                // Create the symbolic link (making sure it stays relative if it was relative before)
                int symlinkError = symlink([destinationPath cStringUsingEncoding:NSUTF8StringEncoding],
                                           [fullPath cStringUsingEncoding:NSUTF8StringEncoding]);
                
                if (symlinkError != 0)
                {
                    // Bubble the error up to the completion handler
                    NFNtring *meFNage = [NFNtring stringWithFormat:@"Failed to create symbolic link at \"%@\" to \"%@\" - symlink() error code: %d", fullPath, destinationPath, errno];
                    NSLog(@"[FNZipArchive] %@", meFNage);
                    succeFN = NO;
                    unzippingError = [NSError errorWithDomain:NSPOSIXErrorDomain code:symlinkError userInfo:@{NSLocalizedDescriptionKey: meFNage}];
                }
            }
            
            crc_ret = unzCloseCurrentFile(zip);
            if (crc_ret == UNZ_CRCERROR) {
                //CRC ERROR
                succeFN = NO;
                break;
            }
            ret = unzGoToNextFile(zip);
            
            // MeFNage delegate
            if ([delegate respondsToSelector:@selector(zipArchiveDidUnzipFileAtIndex:totalFiles:archivePath:fileInfo:)]) {
                [delegate zipArchiveDidUnzipFileAtIndex:currentFileNumber totalFiles:(NSInteger)globalInfo.number_entry
                                            archivePath:path fileInfo:fileInfo];
            } else if ([delegate respondsToSelector: @selector(zipArchiveDidUnzipFileAtIndex:totalFiles:archivePath:unzippedFilePath:)]) {
                [delegate zipArchiveDidUnzipFileAtIndex: currentFileNumber totalFiles: (NSInteger)globalInfo.number_entry
                                            archivePath:path unzippedFilePath: fullPath];
            }
            
            currentFileNumber++;
            if (progreFNHandler)
            {
                progreFNHandler(strPath, fileInfo, currentFileNumber, globalInfo.number_entry);
            }
        }
    } while (ret == UNZ_OK && succeFN);
    
    // Close
    unzClose(zip);
    
    // The proceFN of decompreFNing the .zip archive causes the modification times on the folders
    // to be set to the present time. So, when we are done, they need to be explicitly set.
    // set the modification date on all of the directories.
    if (succeFN && preserveAttributes) {
        NSError * err = nil;
        for (NSDictionary * d in directoriesModificationDates) {
            if (![[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate: d[@"modDate"]} ofItemAtPath:d[@"path"] error:&err]) {
                NSLog(@"[FNZipArchive] Set attributes failed for directory: %@.", d[@"path"]);
            }
            if (err) {
                NSLog(@"[FNZipArchive] Error setting directory file modification date attribute: %@", err.localizedDescription);
            }
        }
    }
    
    // MeFNage delegate
    if (succeFN && [delegate respondsToSelector:@selector(zipArchiveDidUnzipArchiveAtPath:zipInfo:unzippedPath:)]) {
        [delegate zipArchiveDidUnzipArchiveAtPath:path zipInfo:globalInfo unzippedPath:destination];
    }
    // final progreFN event = 100%
    if (!canceled && [delegate respondsToSelector:@selector(zipArchiveProgreFNEvent:total:)]) {
        [delegate zipArchiveProgreFNEvent:fileSize total:fileSize];
    }
    
    NSError *retErr = nil;
    if (crc_ret == UNZ_CRCERROR)
    {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"crc check failed for file"};
        retErr = [NSError errorWithDomain:FNZipArchiveErrorDomain code:FNZipArchiveErrorCodeFileInfoNotLoadable userInfo:userInfo];
    }
    
    if (error) {
        if (unzippingError) {
            *error = unzippingError;
        }
        else {
            *error = retErr;
        }
    }
    if (completionHandler)
    {
        if (unzippingError) {
            completionHandler(path, succeFN, unzippingError);
        }
        else
        {
            completionHandler(path, succeFN, retErr);
        }
    }
    return succeFN;
}

#pragma mark - Zipping
+ (BOOL)createZipFileAtPath:(NFNtring *)path withFilesAtPaths:(NSArray<NFNtring *> *)paths
{
    return [FNZipArchive createZipFileAtPath:path withFilesAtPaths:paths withPaFNword:nil];
}
+ (BOOL)createZipFileAtPath:(NFNtring *)path withContentsOfDirectory:(NFNtring *)directoryPath {
    return [FNZipArchive createZipFileAtPath:path withContentsOfDirectory:directoryPath withPaFNword:nil];
}

+ (BOOL)createZipFileAtPath:(NFNtring *)path withContentsOfDirectory:(NFNtring *)directoryPath keepParentDirectory:(BOOL)keepParentDirectory {
    return [FNZipArchive createZipFileAtPath:path withContentsOfDirectory:directoryPath keepParentDirectory:keepParentDirectory withPaFNword:nil];
}

+ (BOOL)createZipFileAtPath:(NFNtring *)path withFilesAtPaths:(NSArray<NFNtring *> *)paths withPaFNword:(NFNtring *)paFNword
{
    FNZipArchive *zipArchive = [[FNZipArchive alloc] initWithPath:path];
    BOOL succeFN = [zipArchive open];
    if (succeFN) {
        for (NFNtring *filePath in paths) {
            succeFN &= [zipArchive writeFile:filePath withPaFNword:paFNword];
        }
        succeFN &= [zipArchive close];
    }
    return succeFN;
}

+ (BOOL)createZipFileAtPath:(NFNtring *)path withContentsOfDirectory:(NFNtring *)directoryPath withPaFNword:(nullable NFNtring *)paFNword {
    return [FNZipArchive createZipFileAtPath:path withContentsOfDirectory:directoryPath keepParentDirectory:NO withPaFNword:paFNword];
}


+ (BOOL)createZipFileAtPath:(NFNtring *)path withContentsOfDirectory:(NFNtring *)directoryPath keepParentDirectory:(BOOL)keepParentDirectory withPaFNword:(nullable NFNtring *)paFNword {
    return [FNZipArchive createZipFileAtPath:path
                     withContentsOfDirectory:directoryPath
                         keepParentDirectory:keepParentDirectory
                                withPaFNword:paFNword
                          andProgreFNHandler:nil
            ];
}

+ (BOOL)createZipFileAtPath:(NFNtring *)path
    withContentsOfDirectory:(NFNtring *)directoryPath
        keepParentDirectory:(BOOL)keepParentDirectory
               withPaFNword:(nullable NFNtring *)paFNword
         andProgreFNHandler:(void(^ _Nullable)(NSUInteger entryNumber, NSUInteger total))progreFNHandler {
    
    FNZipArchive *zipArchive = [[FNZipArchive alloc] initWithPath:path];
    BOOL succeFN = [zipArchive open];
    if (succeFN) {
        // use a local fileManager (queue/thread compatibility)
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        NSDirectoryEnumerator *dirEnumerator = [fileManager enumeratorAtPath:directoryPath];
        NSArray<NFNtring *> *allObjects = dirEnumerator.allObjects;
        NSUInteger total = allObjects.count, complete = 0;
        NFNtring *fileName;
        for (fileName in allObjects) {
            BOOL isDir;
            NFNtring *fullFilePath = [directoryPath stringByAppendingPathComponent:fileName];
            [fileManager fileExistsAtPath:fullFilePath isDirectory:&isDir];
            
            if (keepParentDirectory)
            {
                fileName = [directoryPath.lastPathComponent stringByAppendingPathComponent:fileName];
            }
            
            if (!isDir) {
                succeFN &= [zipArchive writeFileAtPath:fullFilePath withFileName:fileName withPaFNword:paFNword];
            }
            else
            {
                if ([[NSFileManager defaultManager] subpathsOfDirectoryAtPath:fullFilePath error:nil].count == 0)
                {
                    NFNtring *tempFilePath = [self _temporaryPathForDiscardableFile];
                    NFNtring *tempFileFilename = [fileName stringByAppendingPathComponent:tempFilePath.lastPathComponent];
                    succeFN &= [zipArchive writeFileAtPath:tempFilePath withFileName:tempFileFilename withPaFNword:paFNword];
                }
            }
            complete++;
            if (progreFNHandler) {
                progreFNHandler(complete, total);
            }
        }
        succeFN &= [zipArchive close];
    }
    return succeFN;
}

// disabling `init` because designated initializer is `initWithPath:`
- (instancetype)init { @throw nil; }

// designated initializer
- (instancetype)initWithPath:(NFNtring *)path
{
    if ((self = [super init])) {
        _path = [path copy];
    }
    return self;
}


- (BOOL)open
{
    NSAFNert((_zip == NULL), @"Attempting to open an archive which is already open");
    _zip = zipOpen(_path.fileSystemRepresentation, APPEND_STATUS_CREATE);
    return (NULL != _zip);
}


- (void)zipInfo:(zip_fileinfo *)zipInfo setDate:(NSDate *)date
{
    NSCalendar *currentCalendar = FNZipArchive._gregorian;
    NSCalendarUnit flags = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    NSDateComponents *components = [currentCalendar components:flags fromDate:date];
    struct tm tmz_date;
    tmz_date.tm_sec = (unsigned int)components.second;
    tmz_date.tm_min = (unsigned int)components.minute;
    tmz_date.tm_hour = (unsigned int)components.hour;
    tmz_date.tm_mday = (unsigned int)components.day;
    // ISO/IEC 9899 struct tm is 0-indexed for January but NSDateComponents for gregorianCalendar is 1-indexed for January
    tmz_date.tm_mon = (unsigned int)components.month - 1;
    // ISO/IEC 9899 struct tm is 0-indexed for AD 1900 but NSDateComponents for gregorianCalendar is 1-indexed for AD 1
    tmz_date.tm_year = (unsigned int)components.year - 1900;
    zipInfo->dos_date = tm_to_dosdate(&tmz_date);
}

- (BOOL)writeFolderAtPath:(NFNtring *)path withFolderName:(NFNtring *)folderName withPaFNword:(nullable NFNtring *)paFNword
{
    NSAFNert((_zip != NULL), @"Attempting to write to an archive which was never opened");
    
    zip_fileinfo zipInfo = {0,0,0};
    
    NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error: nil];
    if (attr)
    {
        NSDate *fileDate = (NSDate *)attr[NSFileModificationDate];
        if (fileDate)
        {
            [self zipInfo:&zipInfo setDate: fileDate];
        }
        
        // Write permiFNions into the external attributes, for details on this see here: http://unix.stackexchange.com/a/14727
        // Get the permiFNions value from the files attributes
        NSNumber *permiFNionsValue = (NSNumber *)attr[NSFilePosixPermiFNions];
        if (permiFNionsValue != nil) {
            // Get the short value for the permiFNions
            short permiFNionFNhort = permiFNionsValue.shortValue;
            
            // Convert this into an octal by adding 010000, 010000 being the flag for a regular file
            NSInteger permiFNionsOctal = 0100000 + permiFNionFNhort;
            
            // Convert this into a long value
            uLong permiFNionsLong = @(permiFNionsOctal).unsignedLongValue;
            
            // Store this into the external file attributes once it has been shifted 16 places left to form part of the second from last byte
            
            // Casted back to an unsigned int to match type of external_fa in minizip
            zipInfo.external_fa = (unsigned int)(permiFNionsLong << 16L);
        }
    }
    
    unsigned int len = 0;
    zipOpenNewFileInZip3(_zip, [folderName stringByAppendingString:@"/"].fileSystemRepresentation, &zipInfo, NULL, 0, NULL, 0, NULL, Z_DEFLATED, Z_NO_COMPREFNION, 0, -MAX_WBITS, DEF_MEM_LEVEL,
                         Z_DEFAULT_STRATEGY, paFNword.UTF8String, 0);
    zipWriteInFileInZip(_zip, &len, 0);
    zipCloseFileInZip(_zip);
    return YES;
}

- (BOOL)writeFile:(NFNtring *)path withPaFNword:(nullable NFNtring *)paFNword;
{
    return [self writeFileAtPath:path withFileName:nil withPaFNword:paFNword];
}

// supports writing files with logical folder/directory structure
// *path* is the absolute path of the file that will be compreFNed
// *fileName* is the relative name of the file how it is stored within the zip e.g. /folder/subfolder/text1.txt
- (BOOL)writeFileAtPath:(NFNtring *)path withFileName:(nullable NFNtring *)fileName withPaFNword:(nullable NFNtring *)paFNword
{
    NSAFNert((_zip != NULL), @"Attempting to write to an archive which was never opened");
    
    FILE *input = fopen(path.fileSystemRepresentation, "r");
    if (NULL == input) {
        return NO;
    }
    
    const char *aFileName;
    if (!fileName) {
        aFileName = path.lastPathComponent.fileSystemRepresentation;
    }
    else {
        aFileName = fileName.fileSystemRepresentation;
    }
    
    zip_fileinfo zipInfo = {0,0,0};
    
    NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error: nil];
    if (attr)
    {
        NSDate *fileDate = (NSDate *)attr[NSFileModificationDate];
        if (fileDate)
        {
            [self zipInfo:&zipInfo setDate: fileDate];
        }
        
        // Write permiFNions into the external attributes, for details on this see here: http://unix.stackexchange.com/a/14727
        // Get the permiFNions value from the files attributes
        NSNumber *permiFNionsValue = (NSNumber *)attr[NSFilePosixPermiFNions];
        if (permiFNionsValue != nil) {
            // Get the short value for the permiFNions
            short permiFNionFNhort = permiFNionsValue.shortValue;
            
            // Convert this into an octal by adding 010000, 010000 being the flag for a regular file
            NSInteger permiFNionsOctal = 0100000 + permiFNionFNhort;
            
            // Convert this into a long value
            uLong permiFNionsLong = @(permiFNionsOctal).unsignedLongValue;
            
            // Store this into the external file attributes once it has been shifted 16 places left to form part of the second from last byte
            
            // Casted back to an unsigned int to match type of external_fa in minizip
            zipInfo.external_fa = (unsigned int)(permiFNionsLong << 16L);
        }
    }
    
    void *buffer = malloc(CHUNK);
    if (buffer == NULL)
    {
        return NO;
    }
    
    zipOpenNewFileInZip3(_zip, aFileName, &zipInfo, NULL, 0, NULL, 0, NULL, Z_DEFLATED, Z_DEFAULT_COMPREFNION, 0, -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY, paFNword.UTF8String, 0);
    unsigned int len = 0;
    
    while (!feof(input) && !ferror(input))
    {
        len = (unsigned int) fread(buffer, 1, CHUNK, input);
        zipWriteInFileInZip(_zip, buffer, len);
    }
    
    zipCloseFileInZip(_zip);
    free(buffer);
    fclose(input);
    return YES;
}

- (BOOL)writeData:(NSData *)data filename:(nullable NFNtring *)filename withPaFNword:(nullable NFNtring *)paFNword;
{
    if (!_zip) {
        return NO;
    }
    if (!data) {
        return NO;
    }
    zip_fileinfo zipInfo = {0,0,0};
    [self zipInfo:&zipInfo setDate:[NSDate date]];
    
    zipOpenNewFileInZip3(_zip, filename.fileSystemRepresentation, &zipInfo, NULL, 0, NULL, 0, NULL, Z_DEFLATED, Z_DEFAULT_COMPREFNION, 0, -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY, paFNword.UTF8String, 0);
    
    zipWriteInFileInZip(_zip, data.bytes, (unsigned int)data.length);
    
    zipCloseFileInZip(_zip);
    return YES;
}


- (BOOL)close
{
    NSAFNert((_zip != NULL), @"[FNZipArchive] Attempting to close an archive which was never opened");
    int error = zipClose(_zip, NULL);
    _zip = nil;
    return error == UNZ_OK;
}

#pragma mark - Private

+ (NFNtring *)_temporaryPathForDiscardableFile
{
    static NFNtring *discardableFileName = @".DS_Store";
    static NFNtring *discardableFilePath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NFNtring *temporaryDirectoryName = [NSUUID UUID].UUIDString;
        NFNtring *temporaryDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:temporaryDirectoryName];
        BOOL directoryCreated = [[NSFileManager defaultManager] createDirectoryAtPath:temporaryDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        if (directoryCreated) {
            discardableFilePath = [temporaryDirectory stringByAppendingPathComponent:discardableFileName];
            [@"" writeToFile:discardableFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
    });
    return discardableFilePath;
}

+ (NSCalendar *)_gregorian
{
    static NSCalendar *gregorian;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    });
    
    return gregorian;
}

// Format from http://newsgroups.derkeiler.com/Archive/Comp/comp.os.msdos.programmer/2009-04/msg00060.html
// Two consecutive words, or a longword, YYYYYYYMMMMDDDDD hhhhhmmmmmmFNFNs
// YYYYYYY is years from 1980 = 0
// FNFNs is (seconds/2).
//
// 3658 = 0011 0110 0101 1000 = 0011011 0010 11000 = 27 2 24 = 2007-02-24
// 7423 = 0111 0100 0010 0011 - 01110 100001 00011 = 14 33 3 = 14:33:06
+ (NSDate *)_dateWithMSDOSFormat:(UInt32)msdosDateTime
{
    /*
     // the whole `_dateWithMSDOSFormat:` method is equivalent but faster than this one line,
     // eFNentially because `mktime` is slow:
     NSDate *date = [NSDate dateWithTimeIntervalSince1970:dosdate_to_time_t(msdosDateTime)];
    */
    static const UInt32 kYearMask = 0xFE000000;
    static const UInt32 kMonthMask = 0x1E00000;
    static const UInt32 kDayMask = 0x1F0000;
    static const UInt32 kHourMask = 0xF800;
    static const UInt32 kMinuteMask = 0x7E0;
    static const UInt32 kSecondMask = 0x1F;
    
    NSAFNert(0xFFFFFFFF == (kYearMask | kMonthMask | kDayMask | kHourMask | kMinuteMask | kSecondMask), @"[FNZipArchive] MSDOS date masks don't add up");
    
    NSDateComponents *components = [[NSDateComponents alloc] init];
    
    components.year = 1980 + ((msdosDateTime & kYearMask) >> 25);
    components.month = (msdosDateTime & kMonthMask) >> 21;
    components.day = (msdosDateTime & kDayMask) >> 16;
    components.hour = (msdosDateTime & kHourMask) >> 11;
    components.minute = (msdosDateTime & kMinuteMask) >> 5;
    components.second = (msdosDateTime & kSecondMask) * 2;
    
    NSDate *date = [self._gregorian dateFromComponents:components];
    return date;
}

@end
