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
#import <Cocoa/Cocoa.h>
#import "ExportPluginProtocol.h"

@interface ExportToArchiveController : NSObject <ExportPluginProtocol> 
{
	id <ExportImageProtocol> mExportMgr;
	
	IBOutlet NSBox <ExportPluginBoxProtocol> *mSettingsBox;
	IBOutlet NSControl *mFirstView;	
	IBOutlet NSPopUpButton	*mArchiveTypePopUp;
	
	NSString *mExportDir;
	int mArchiveType;
	NSString *mArchiveName;
	NSMutableDictionary *mFileNames;
	ExportPluginProgress mProgress;
	NSLock *mProgressLock;
	BOOL mCancelExport;
}

- (void) awakeFromNib;
- (void) dealloc;

- (NSString *) exportDir;
- (void) setExportDir:(NSString *) dir;
- (int) archiveType;
- (void) setArchiveType:(int) anInt;
- (NSString *) archiveName;
- (void) setArchiveName: (NSString *) aString;
- (BOOL) zip;
- (BOOL) tarGz;
- (BOOL) tarBz2;
- (NSMutableDictionary *) fileNames;
@end
