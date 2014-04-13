/* 
	Export to Archive iPhoto Plugin
	Copyright © 2007 Joey Gibson <joey@joeygibson.com>
 
	This program is free software; you can redistribute it and/or
	modify it under the terms of the GNU General Public License
	as published by the Free Software Foundation; either version 2
	of the License, or (at your option) any later version.
 
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
 
	You should have received a copy of the GNU General Public License
	along with this program; if not, write to the Free Software
	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */
#import "ExportToArchiveController.h"
#import <unistd.h>
#import <errno.h>
@implementation ExportToArchiveController

- (void) awakeFromNib
{
	[mArchiveTypePopUp selectItemWithTag:2];
	srandom(time(NULL));
}

- (id) initWithExportImageObj: (id <ExportImageProtocol>) obj
{
	if(self = [super init])
	{
		mExportMgr = obj;
		mProgress.message = nil;
		mProgressLock = [[NSLock alloc] init];
		mFileNames = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

- (void) dealloc
{
	[mExportDir release];
	[mArchiveName release];
	[mProgressLock release];
	[mProgress.message release];
	[mFileNames release];
	
	[super dealloc];
}

- (NSString *) exportDir
{
	return mExportDir;
}

- (void) setExportDir: (NSString *) dir
{
	[mExportDir release];
	mExportDir = [dir retain];
}

- (int) archiveType
{
	return mArchiveType;
}

- (void) setArchiveType: (int) anInt
{
	mArchiveType = anInt;
}

- (NSView <ExportPluginBoxProtocol> *) settingsView
{
	return mSettingsBox;
}

- (NSView *) firstView
{
	return mFirstView;
}

- (void) viewWillBeActivated
{

}

- (void) viewWillBeDeactivated
{

}

- (NSString *) requiredFileType
{
	switch ([mArchiveTypePopUp selectedTag]) {
		case 0: return @"tar.bz2";
		case 1: return @"tar.gz";
		case 2: return @"zip";
		default: return @"zip";
	}
}

- (BOOL) wantsDestinationPrompt
{
	return YES;
}

- (NSString*) getDestinationPath
{
	return @"";
}

- (NSString *) defaultFileName
{
	return @"Pictures";	
}

- (NSString *) defaultDirectory
{
	return @"~/";
}

- (BOOL) treatSingleSelectionDifferently
{
	return NO;
}

- (BOOL) handlesMovieFiles
{
	return YES;
}

- (BOOL) validateUserCreatedPath:(NSString*) path
{
	return NO;
}

- (void) clickExport
{
	[mExportMgr clickExport];
}

- (void) startExport: (NSString *) path
{
	[mFileNames removeAllObjects];
	
	NSFileManager *fileMgr = [NSFileManager defaultManager];
	
	[self setArchiveType: [mArchiveTypePopUp selectedTag]];

	NSString *tmpDirectory = NSTemporaryDirectory();	

	NSString *tmpPath = [tmpDirectory stringByAppendingFormat: @"/exportToArchive-%d-%d-%d-%d", 
		(random() % 100), (random() % 100), (random() % 100), (random() % 100)];
	
	[self setExportDir: tmpPath];
	[fileMgr createDirectoryAtPath: tmpPath	attributes: nil];

	[self setArchiveName: path];
	
	[mExportMgr startExport];		
}

- (void) performExport: (NSString *) path
{
	int count = [mExportMgr imageCount];
	BOOL succeeded = YES;
	mCancelExport = NO;
	
	[self lockProgress];
	mProgress.indeterminateProgress = NO;
	mProgress.totalItems = count - 1;
	[mProgress.message autorelease];
	mProgress.message = @"Exporting";
	[self unlockProgress];
	
	NSDate *startDate = [NSDate date];
	NSString *dest;
	
	@try
	{		
		int rc;
		int i;
		for(i = 0; mCancelExport == NO && succeeded == YES && i < count; i++)
		{
			[self lockProgress];
			mProgress.currentItem = i;
			[mProgress.message autorelease];
			mProgress.message = [[NSString stringWithFormat: @"Image %d of %d",
				i + 1, count] retain];
			[self unlockProgress];

			NSString *source = [mExportMgr imagePathAtIndex: i];
			
			NSString *fileName;
			
			if ([mExportMgr respondsToSelector: @selector(imageFileNameAtIndex:)]) {
				fileName = [mExportMgr imageFileNameAtIndex: i];
			} else {
				fileName = [[mExportMgr imagePathAtIndex: i] lastPathComponent];			
			}
			
			NSNumber *fileNameCount = [[self fileNames] objectForKey: fileName];
			
			if (fileNameCount) {
				NSString *ext = [fileName pathExtension];
				NSRange range = [fileName rangeOfString: ext options: NSBackwardsSearch];
				NSString *newFileName = [fileName substringToIndex: range.location - 1];
				newFileName = [newFileName stringByAppendingFormat: @"_%d.%@", [fileNameCount intValue], ext];
							
				dest = [[self exportDir] stringByAppendingPathComponent: newFileName];
				fileNameCount = [NSNumber numberWithInt: [fileNameCount intValue] + 1];
			} else {
				dest = [[self exportDir] stringByAppendingPathComponent: fileName];
				fileNameCount = [NSNumber numberWithInt: 1];
			}
			
			[[self fileNames] setObject: fileNameCount forKey: fileName];
				
			NSLog(@"Exporting to %@", dest);
			
			rc = symlink([source UTF8String], [dest UTF8String]);

			NSLog(@"%@ => %@, %d, %d", source, dest, rc, errno);
			
			succeeded = (rc == 0);
		}
		
		if (succeeded) {		
			[self lockProgress];
			mProgress.indeterminateProgress = YES;
			[mProgress.message autorelease];
			mProgress.message = @"Compressing files";
			[self unlockProgress];
			
			NSFileManager *fileManager = [NSFileManager defaultManager];	
			NSString *origDir = [fileManager currentDirectoryPath];
			
			if ([fileManager changeCurrentDirectoryPath: [self exportDir]]) {
				switch ([self archiveType]) {
					case 0: succeeded = [self tarBz2];
						break;
					case 1: succeeded = [self tarGz];
						break;
					case 2: succeeded = [self zip];
						break;
				}
			} else {
				NSLog(@"Can't change directories.");
				return;
			}
			
			[fileManager changeCurrentDirectoryPath: origDir];
		}
		
		if (!succeeded) {
			[self lockProgress];
			[mProgress.message autorelease];
			mProgress.message = [[NSString stringWithFormat: @"Unable to create %@", [self archiveName]] retain];
			[self cancelExport];
			mProgress.shouldCancel = YES;
			[self unlockProgress];
			return;
		}
		
		[self lockProgress];
		[mProgress.message autorelease];
		mProgress.message = nil;
		mProgress.shouldStop = YES;
		[self unlockProgress];
	}
	@finally
	{
		[[NSFileManager defaultManager] removeFileAtPath: [self exportDir] handler: nil];
	}
	
	NSDate *endDate = [NSDate date];
	
	float elapsedTime = [endDate timeIntervalSinceDate: startDate];
	NSLog(@"Archiving %d photos took %f seconds.", count, elapsedTime);
}

- (BOOL) tarGz
{
	NSTask *gzTask = [[NSTask alloc] init];
	[gzTask setLaunchPath: @"/usr/bin/tar"];
	[gzTask setArguments:
		[NSArray arrayWithObjects: @"-czhf", [self archiveName], @".", nil]];
	
	[gzTask launch];
	[gzTask waitUntilExit];
	
	int rc = [gzTask terminationStatus];
	
	[gzTask release];
	
	return rc == 0;
}

- (BOOL) tarBz2
{
	NSTask *bz2Task = [[NSTask alloc] init];
	[bz2Task setLaunchPath: @"/usr/bin/tar"];
	[bz2Task setArguments:
		[NSArray arrayWithObjects: @"-cjhf", [self archiveName], @".", nil]];
	
	[bz2Task launch];
	[bz2Task waitUntilExit];
	
	int rc = [bz2Task terminationStatus];
	
	[bz2Task release];
	
	return rc == 0;
}

-(BOOL) zip
{
	NSTask *zipTask = [[NSTask alloc] init];
	[zipTask setLaunchPath: @"/usr/bin/zip"];
	[zipTask setArguments:
		[NSArray arrayWithObjects: @"-r", [self archiveName], @".", nil]];
	
	[zipTask launch];
	[zipTask waitUntilExit];

	int rc = [zipTask terminationStatus];
	
	[zipTask release];
	
	return rc == 0;
}

- (ExportPluginProgress *) progress
{
	return &mProgress;
}

- (void) lockProgress
{
	[mProgressLock lock];
}

- (void) unlockProgress
{
	[mProgressLock unlock];
}

- (void) cancelExport
{
	mCancelExport = YES;
}

- (NSString *) name
{
	return @"Simple File Exporter";
}

- (NSString *) archiveName
{	
	return mArchiveName;
}

- (void) setArchiveName: (NSString *) aString
{
	[mArchiveName release];
	mArchiveName = [aString retain];
}

- (NSMutableDictionary *) fileNames
{
	return mFileNames;
}
@end
