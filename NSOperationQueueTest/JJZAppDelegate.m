//
//  JJZAppDelegate.m
//  NSOperationQueueTest
//
//  Created by Ryan C. Payne on 2/12/13.
//  Copyright (c) 2013 BullittSystems, Inc. All rights reserved.
//

#import "JJZAppDelegate.h"

@interface JJZAppDelegate ()
@property (nonatomic, strong) NSOperationQueue     *queue;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@end

@implementation JJZAppDelegate
{
    NSUInteger _operationGroupCount;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSOperationQueue *operationQueue = [NSOperationQueue new];
    operationQueue.maxConcurrentOperationCount = 1;

    self.queue = operationQueue;

    self.semaphore = dispatch_semaphore_create(1);

    [self.pauseOperationsButton setEnabled:YES];
    [self.resumeOperationsButton setEnabled:NO];

    [self.logMessageArrayController setPreservesSelection:YES];
}

- (IBAction)enqueueOperations:(id)sender
{
    [self performOperationalMagic];
}

- (IBAction)pauseOperations:(id)sender
{
    if (![self.queue isSuspended])
    {
        [self.queue setSuspended:YES];
        [self.pauseOperationsButton setEnabled:NO];
        [self.resumeOperationsButton setEnabled:YES];

        [self addLogMessage:@"Operation Queue Suspended"];
    }
}

- (IBAction)resumeOperations:(id)sender
{
    if ([self.queue isSuspended])
    {
        [self.queue setSuspended:NO];
        [self.pauseOperationsButton setEnabled:YES];
        [self.resumeOperationsButton setEnabled:NO];

        [self addLogMessage:@"Operation Queue Resumed"];
    }
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
        [self.logMessageArrayController addObject:@{ @"LogMessage" : logMessage, @"Date" : [NSDate date] }];

        if (self.followTableViewCheckBox.state == NSOnState)
        {
            [self.tableView scrollRowToVisible:([[self.logMessageArrayController content] count] - 1)];
        }
    });
}

- (void)copy:(id)sender
{
    NSMutableArray *messages = [NSMutableArray array];

    [[self.logMessageArrayController selectedObjects] enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
        NSString *message = [NSString stringWithFormat:@"%@ - %@", [self.dateFormatter stringFromDate:obj[@"Date"]], obj[@"LogMessage"]];
        [messages addObject:message];
    }];

    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    [pasteBoard clearContents];
    [pasteBoard writeObjects:messages];
}

- (NSUInteger)randomWaitTime
{
    return arc4random_uniform(9) + 1;
}

- (NSUInteger)randomNumberOfOperations
{
    return arc4random_uniform(24) + 1;
}

#pragma mark - Operation Maintenance
- (NSUInteger)incrementAndReturnOperationGroupCount
{
    NSUInteger count = 0;

    @synchronized(self)
    {
        count = ++_operationGroupCount;
    }

    return count;
}

- (void)performOperationalMagic
{
    NSUInteger operationGroupCount = [self incrementAndReturnOperationGroupCount];
    [self addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Creating operation group", operationGroupCount]];

    NSUInteger numberOfOperations = [self randomNumberOfOperations];

    NSArray *operations = [self generateOperationsWithOperationGroupCount:operationGroupCount numberOfOperations:numberOfOperations];

    [self addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Enqueuing operation group", operationGroupCount]];
    [self.queue addOperations:operations waitUntilFinished:NO];
    [self addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation group enqueued", operationGroupCount]];
}

- (NSArray *)generateOperationsWithOperationGroupCount:(NSUInteger)operationGroupCount numberOfOperations:(NSUInteger)numberOfOperations
{
    [self addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Creating %lu operations", operationGroupCount, numberOfOperations]];

    JJZAppDelegate *__weak weakSelf = self;
    NSMutableArray         *operations = [NSMutableArray array];
    NSInteger              operationCount = 1;

    // Quasi-begin handler
    [operations addObject:[NSBlockOperation blockOperationWithBlock:^{
            JJZAppDelegate *__strong strongSelf = weakSelf;

            if (strongSelf)
            {
                [strongSelf addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation: %lu - Initialization", operationGroupCount, operationCount]];
            }
        }]];

    for (NSUInteger index = 0; index < numberOfOperations; index++)
    {
        operationCount++;
        [operations addObject:[self createOperationForOperationGroupCount:operationGroupCount operationCount:operationCount]];
    }

    operationCount++;

    // RCP: Quasi-completion handler
    [operations addObject:[NSBlockOperation blockOperationWithBlock:^{
            JJZAppDelegate *__strong strongSelf = weakSelf;

            if (strongSelf)
            {
                [strongSelf addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation: %lu - Final Aggregator - Start", operationGroupCount, operationCount]];

                [strongSelf addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation: %lu - Final Aggregator - Waiting for semaphore", operationGroupCount, operationCount]];
                if (dispatch_semaphore_wait(strongSelf.semaphore, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 300)) == 0)
                {
                    [strongSelf addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation: %lu - Final Aggregator - Received semaphore", operationGroupCount, operationCount]];

                    NSUInteger waitTime = [strongSelf randomWaitTime];
                    [strongSelf addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation: %lu - Final Aggregator - Sleeping for %lu seconds", operationGroupCount, operationCount, waitTime]];
                    [NSThread sleepForTimeInterval:waitTime];
                }
                else
                {
                    [strongSelf addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation: %lu - Final Aggregator - Failed to receive semaphore", operationGroupCount, operationCount]];
                }

                // Cleanup!
                [strongSelf addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation: %lu - Final Aggregator - Complete, Signaling semaphore", operationGroupCount, operationCount]];
                dispatch_semaphore_signal(strongSelf.semaphore);
            }
        }]];

    // Lastly, make all of these operations dependent upon eachother.
    NSOperation *__block previousOperation = nil;

    [operations enumerateObjectsUsingBlock:^(NSOperation *currentOperation, NSUInteger idx, BOOL *stop) {
        if (previousOperation != nil)
        {
            [currentOperation addDependency:previousOperation];
        }

        previousOperation = currentOperation;
    }];

    [self addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Created %lu operations for to handle %lu events", operationGroupCount, [operations count], numberOfOperations]];

    return operations;
}

- (NSOperation *)createOperationForOperationGroupCount:(NSUInteger)operationGroupCount operationCount:(NSUInteger)operationCount
{
    JJZAppDelegate *__weak weakSelf = self;

    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        JJZAppDelegate *__strong strongSelf = weakSelf;

        if (strongSelf != nil)
        {
            [strongSelf addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation: %lu - Request - Start", operationGroupCount, operationCount]];
            [strongSelf addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation: %lu - Request - Waiting for semaphore", operationGroupCount, operationCount]];
            if (dispatch_semaphore_wait(strongSelf.semaphore, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 300)) == 0)
            {
                [strongSelf addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation: %lu - Request - Received semaphore", operationGroupCount, operationCount]];

                NSUInteger delayInSeconds = [strongSelf randomWaitTime];

                [strongSelf addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation: %lu - Request - Sleeping for %lu seconds", operationGroupCount, operationCount, delayInSeconds]];

                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_current_queue(), ^(void){
                        [strongSelf addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation: %lu - Response - Start", operationGroupCount, operationCount]];

                        NSUInteger waitTime = [strongSelf randomWaitTime];
                        [strongSelf addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation: %lu - Response - Sleeping for %lu seconds", operationGroupCount, operationCount, waitTime]];
                        [NSThread sleepForTimeInterval:waitTime];

                        [strongSelf addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation: %lu - Response - Signaling semaphore", operationGroupCount, operationCount]];
                        dispatch_semaphore_signal(strongSelf.semaphore);
                        [strongSelf addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation: %lu - Complete", operationGroupCount, operationCount]];
                    });
            }
            else
            {
                [strongSelf addLogMessage:[NSString stringWithFormat:@"Operation Group: %lu - Operation: %lu - Request - Failed to receive semaphore", operationGroupCount, operationCount]];
            }
        }
    }];

    return operation;
}

@end
