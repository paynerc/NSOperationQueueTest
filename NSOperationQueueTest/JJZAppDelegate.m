//
//  JJZAppDelegate.m
//  NSOperationQueueTest
//
//  Created by Ryan C. Payne on 2/12/13.
//  Copyright (c) 2013 BullittSystems, Inc. All rights reserved.
//

#import "JJZAppDelegate.h"

@implementation JJZAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    
    
}

- (IBAction)enqueueOperations:(id)sender
{
    NSString *message = [NSString stringWithFormat:@"I pushed the bunton at: %@", [NSDate date]];
    
    [self addLogMessage:message];
}

- (IBAction)clearDisplay:(id)sender
{
    [[self.logMessageArrayController content] removeAllObjects];
    [self.tableView reloadData];
    [self.tableView scrollRowToVisible:0];
}


- (void)addLogMessage:(NSString *)logMessage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.logMessageArrayController addObject:@{ @"LogMessage" : logMessage }];

        if (self.followTableViewCheckBox.state == NSOnState)
        {
            [self.tableView scrollRowToVisible:([[self.logMessageArrayController content] count] - 1)];
        }
    });
}

@end
