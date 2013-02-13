//
//  JJZAppDelegate.h
//  NSOperationQueueTest
//
//  Created by Ryan C. Payne on 2/12/13.
//  Copyright (c) 2013 BullittSystems, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface JJZAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow        *window;
@property (weak) IBOutlet NSArrayController *logMessageArrayController;
@property (weak) IBOutlet NSTableView       *tableView;
@property (weak) IBOutlet NSButton          *followTableViewCheckBox;
@property (weak) IBOutlet NSButton          *enqueueButton;
@property (weak) IBOutlet NSButton          *clearDisplayButton;

- (IBAction)enqueueOperations:(id)sender;
- (IBAction)clearDisplay:(id)sender;

@end
