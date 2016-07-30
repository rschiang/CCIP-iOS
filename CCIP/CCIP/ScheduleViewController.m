//
//  ScheduleViewController.m
//  CCIP
//
//  Created by FrankWu on 2016/7/17.
//  Copyright © 2016年 CPRTeam. All rights reserved.
//

#import "ScheduleViewController.h"
#import "UISegmentedControl+addition.h"
#import "GatewayWebService/GatewayWebService.h"
#import "ProgramDetailViewController.h"
#import "NSInvocation+addition.h"
#import <CoreText/CoreText.h>
#import "BLKFlexibleHeightBar.h"
#import "BLKDelegateSplitter.h"
#import "SquareCashStyleBehaviorDefiner.h"

#define TOOLBAR_MIN_HEIGHT  (22.0f)
#define TOOLBAR_HEIGHT      (44.0f)

#define MAX_TABLE_VIEW      (CGRectMake(0, TOOLBAR_HEIGHT, self.view.bounds.size.width, self.view.bounds.size.height - _bottomGuide - TOOLBAR_HEIGHT))
#define MIN_TABLE_VIEW      (CGRectMake(0, TOOLBAR_MIN_HEIGHT, self.view.bounds.size.width, self.view.bounds.size.height - _bottomGuide - TOOLBAR_MIN_HEIGHT))

@interface ScheduleViewController ()

@property (strong, nonatomic) BLKFlexibleHeightBar *myBar;
@property (strong, nonatomic) BLKDelegateSplitter *delegateSplitter;
@property (strong, nonatomic) UIToolbar *toolbar;
@property (strong, nonatomic) UIToolbar *labelToolbar;
@property (strong, nonatomic) UILabel *segmentedLabel;
@property (strong, nonatomic) UISegmentedControl *segmentedControl;
@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) UIRefreshControl *refreshControl;

@property CGFloat topGuide;
@property CGFloat bottomGuide;

@property BOOL canScrollHide;

@property BOOL startScroll;
@property CGFloat lastContentOffsetY;
@property CGFloat changeHeight;
@property NSInteger swipeDirection;
#define SWIPE_UP    1
#define SWIPE_DOWN  -1
@property CGFloat deltaY;
#define DELTAY_SIZE 22

@property NSUInteger refreshingCountDown;

@property (strong, nonatomic) NSArray *rooms;
@property (strong, nonatomic) NSArray *programs;
@property (strong, nonatomic) NSArray *program_types;

@property (strong, nonatomic) NSArray *segmentsTextArray;

@property (strong, nonatomic) NSMutableDictionary *program_date;
@property (strong, nonatomic) NSMutableDictionary *program_date_section;


@end

@implementation ScheduleViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.view setBackgroundColor:[UIColor whiteColor]];
    
    _topGuide = 0.0;
    _bottomGuide = 0.0;
    if (self.navigationController.navigationBar.translucent) {
        if (self.prefersStatusBarHidden == NO) _topGuide += 20;
        if (self.navigationController.navigationBarHidden == NO) _topGuide += self.navigationController.navigationBar.bounds.size.height;
    }
    if (self.tabBarController.tabBar.hidden == NO) _bottomGuide += self.tabBarController.tabBar.bounds.size.height;
    
    // setting for ScrollHide
    _canScrollHide = NO;
    _lastContentOffsetY = _topGuide;
    _changeHeight = 0;
    
    // ... setting up the SegmentedControl here ...
    _segmentedControl = [UISegmentedControl new] ;
    [_segmentedControl setFrame:CGRectMake(0, 0, 200, 30)];
    [_segmentedControl addTarget:self
                          action:@selector(segmentedControlValueDidChange:)
                forControlEvents:UIControlEventValueChanged];
    [_segmentedControl setTintColor:[UIColor colorWithRed:61.0f/255.0f
                                                    green:152.0f/255.0f
                                                     blue:60.0f/255.0f
                                                    alpha:1.0f]];
    
    _myBar = [[BLKFlexibleHeightBar alloc] initWithFrame:CGRectMake(0, _topGuide, self.view.frame.size.width, TOOLBAR_HEIGHT)];
    _myBar.maximumBarHeight = TOOLBAR_HEIGHT;
    _myBar.minimumBarHeight = TOOLBAR_MIN_HEIGHT;
    _myBar.behaviorDefiner = [SquareCashStyleBehaviorDefiner new];
    [_myBar.layer setShadowOffset:CGSizeMake(0, 1.0f/UIScreen.mainScreen.scale)];
    [_myBar.layer setShadowRadius:0];
    [_myBar.layer setShadowColor:[UIColor blackColor].CGColor];
    [_myBar.layer setShadowOpacity:0.25f];
    [_myBar.layer setBackgroundColor:[[[self.navigationController view] backgroundColor] CGColor]];
    self.delegateSplitter = [[BLKDelegateSplitter alloc] initWithFirstDelegate:_myBar.behaviorDefiner secondDelegate:self];
    
    // ... setting up the Toolbar here ...
    _toolbar = [UIToolbar new];
    [_toolbar setFrame:CGRectMake(0, 0, self.view.bounds.size.width, TOOLBAR_HEIGHT)];
    [_toolbar setTranslucent:YES];
    [_toolbar setBackgroundColor:[UIColor clearColor]];
    [_toolbar setBackgroundImage:[UIImage new]
              forToolbarPosition:UIToolbarPositionAny
                      barMetrics:UIBarMetricsDefault];
    [_myBar addSubview:_toolbar];
    
    // ... setting up the label toolbar here ...
    _labelToolbar = [UIToolbar new];
    [_labelToolbar setFrame:CGRectMake(0, 0, self.view.bounds.size.width, TOOLBAR_MIN_HEIGHT)];
    [_labelToolbar setTranslucent:YES];
    [_labelToolbar setBackgroundColor:[UIColor clearColor]];
    [_labelToolbar setBackgroundImage:[UIImage new]
                   forToolbarPosition:UIToolbarPositionAny
                           barMetrics:UIBarMetricsDefault];
    [_myBar addSubview:_labelToolbar];
    
    //// toolbar attributes
    BLKFlexibleHeightBarSubviewLayoutAttributes *toolbarInitialLayoutAttributes = [BLKFlexibleHeightBarSubviewLayoutAttributes new];
    toolbarInitialLayoutAttributes.size = _toolbar.frame.size;
    toolbarInitialLayoutAttributes.center = CGPointMake(CGRectGetMidX(_toolbar.bounds), CGRectGetMidY(_toolbar.bounds));
    // This is what we want the bar to look like at its maximum height (progress == 0.0)
    [_toolbar addLayoutAttributes:toolbarInitialLayoutAttributes forProgress:0.0];
    
    // Create a final set of layout attributes based on the same values as the initial layout attributes
    BLKFlexibleHeightBarSubviewLayoutAttributes *toolbarFinalLayoutAttributes = [[BLKFlexibleHeightBarSubviewLayoutAttributes alloc] initWithExistingLayoutAttributes:toolbarInitialLayoutAttributes];
    toolbarFinalLayoutAttributes.alpha = 0.0;
    toolbarFinalLayoutAttributes.size = _labelToolbar.frame.size;
    toolbarFinalLayoutAttributes.center = CGPointMake(CGRectGetMidX(_labelToolbar.bounds), CGRectGetMidY(_labelToolbar.bounds));
    // This is what we want the bar to look like at its minimum height (progress == 1.0)
    [_toolbar addLayoutAttributes:toolbarFinalLayoutAttributes forProgress:1.0];
    
    //// label toolbar attributes
    BLKFlexibleHeightBarSubviewLayoutAttributes *lableToolbarInitialLayoutAttributes = [BLKFlexibleHeightBarSubviewLayoutAttributes new];
    lableToolbarInitialLayoutAttributes.size = _toolbar.frame.size;
    lableToolbarInitialLayoutAttributes.center = CGPointMake(CGRectGetMidX(_toolbar.bounds), CGRectGetMidY(_toolbar.bounds));
    lableToolbarInitialLayoutAttributes.alpha = 0.0;
    // This is what we want the bar to look like at its maximum height (progress == 0.0)
    [_labelToolbar addLayoutAttributes:lableToolbarInitialLayoutAttributes forProgress:0.0];
    
    // Create a final set of layout attributes based on the same values as the initial layout attributes
    BLKFlexibleHeightBarSubviewLayoutAttributes *labelToolbarFinalLayoutAttributes = [[BLKFlexibleHeightBarSubviewLayoutAttributes alloc] initWithExistingLayoutAttributes:lableToolbarInitialLayoutAttributes];
    labelToolbarFinalLayoutAttributes.size = _labelToolbar.frame.size;
    labelToolbarFinalLayoutAttributes.center = CGPointMake(CGRectGetMidX(_labelToolbar.bounds), CGRectGetMidY(_labelToolbar.bounds));
    labelToolbarFinalLayoutAttributes.alpha = 1.0;
    // This is what we want the bar to look like at its minimum height (progress == 1.0)
    [_labelToolbar addLayoutAttributes:labelToolbarFinalLayoutAttributes forProgress:1.0];
    
    
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                   target:nil
                                                                                   action:nil];
    // ... setting up label here ...
    _segmentedLabel = [UILabel new];
    [_segmentedLabel setFrame:CGRectMake(0, 0, self.view.bounds.size.width, TOOLBAR_MIN_HEIGHT)];
    [_segmentedLabel setTextAlignment:NSTextAlignmentCenter];
    [_segmentedLabel setFont:[UIFont systemFontOfSize:12.0f weight:2.0f]];
    UIBarButtonItem *segmentedLabelItem = [[UIBarButtonItem alloc] initWithCustomView:(UIView *)_segmentedLabel];
    NSArray *labelBarArray = @[flexibleSpace, segmentedLabelItem, flexibleSpace];
    [_labelToolbar setItems:labelBarArray];
    
    // ... setting up the Toolbar's Items here ...
    UIBarButtonItem *segmentedControlButtonItem = [[UIBarButtonItem alloc] initWithCustomView:(UIView *)_segmentedControl];
    NSArray *barArray = @[flexibleSpace, segmentedControlButtonItem, flexibleSpace];
    [_toolbar setItems:barArray];
    
    // ... setting up the TableView here ...
    _tableView = [UITableView new];
    [_tableView setFrame:MAX_TABLE_VIEW];
    [_tableView setShowsHorizontalScrollIndicator:YES];
    [_tableView setDelegate:(id<UITableViewDelegate>)self.delegateSplitter];
    [_tableView setDataSource:self];
    [self.view addSubview:_tableView];
    
    [self.view bringSubviewToFront:_myBar];
    
    // ... setting up the RefreshControl here ...
    UITableViewController *tableViewController = [UITableViewController new];
    tableViewController.tableView = self.tableView;
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self
                            action:@selector(refreshData)
                  forControlEvents:UIControlEventValueChanged];
    tableViewController.refreshControl = self.refreshControl;
    
    [self refreshData];
    
    
    
    [self.view addSubview:_myBar];
    
    
//    self.tableView.delegate = self;

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)refreshData {
    [self.refreshControl beginRefreshing];
    self.refreshingCountDown = 3;
    
    GatewayWebService *roome_ws = [[GatewayWebService alloc] initWithURL:ROOM_DATA_URL];
    [roome_ws sendRequest:^(NSArray *json, NSString *jsonStr) {
        if (json != nil) {
            NSLog(@"%@", json);
            self.rooms = json;
        }
        [self endRefreshingWithCountDown];
    }];
    
    GatewayWebService *program_ws = [[GatewayWebService alloc] initWithURL:PROGRAM_DATA_URL];
    [program_ws sendRequest:^(NSArray *json, NSString *jsonStr) {
        if (json != nil) {
            NSLog(@"%@", json);
            self.programs = json;
            
            [self setScheduleDate];
        }
        [self endRefreshingWithCountDown];
    }];
    
    GatewayWebService *program_type_ws = [[GatewayWebService alloc] initWithURL:PROGRAM_TYPE_DATA_URL];
    [program_type_ws sendRequest:^(NSArray *json, NSString *jsonStr) {
        if (json != nil) {
            NSLog(@"%@", json);
            self.program_types = json;
        }
        [self endRefreshingWithCountDown];
    }];
}

-(void)endRefreshingWithCountDown{
    self.refreshingCountDown -= 1;
    if (self.refreshingCountDown == 0) {
        [self.refreshControl endRefreshing];
        [self.tableView reloadData];
    }
}

-(void)setScheduleDate{
    static NSDateFormatter *formatter_full = nil;
    if (formatter_full == nil) {
        formatter_full = [NSDateFormatter new];
        [formatter_full setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
        [formatter_full setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    }
    
    static NSDateFormatter *formatter_date = nil;
    if (formatter_date == nil) {
        formatter_date = [NSDateFormatter new];
        [formatter_date setDateFormat:@"MM/dd"];
    }
    
    static NSDate *startTime;
    static NSString *time_date;
    
    NSMutableDictionary *datesDict = [NSMutableDictionary new];

    for (NSDictionary *program in self.programs) {
        startTime = [formatter_full dateFromString:[program objectForKey:@"starttime"]];
        time_date = [formatter_date stringFromDate:startTime];
        
        NSMutableArray *tempArray = [datesDict objectForKey:time_date];
        if (tempArray == nil) {
            tempArray = [NSMutableArray new];
        }
        [tempArray addObject:program];
        [datesDict setObject:tempArray forKey:time_date];
    }
    
    self.program_date = datesDict;
    self.segmentsTextArray = [[self.program_date allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    [self.segmentedControl resetAllSegments:self.segmentsTextArray];
    
    [self checkScheduleDate];
    
    // UIApplicationShortcutIcon
    // UIApplicationShortcutItem
    
    NSMutableArray *shortcutItems = [NSMutableArray new];
    
    UIApplicationShortcutItem * shortcutItem;
    shortcutItem =[[UIApplicationShortcutItem alloc] initWithType:@"Checkin"
                                                   localizedTitle:@"day1 報到"
                                                localizedSubtitle:nil
                                                             icon:[UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypeTaskCompleted]
                                                         userInfo:nil];
    [shortcutItems addObject:shortcutItem];
    
    shortcutItem =[[UIApplicationShortcutItem alloc] initWithType:@"Checkin"
                                                   localizedTitle:@"day1 領便當"
                                                localizedSubtitle:nil
                                                             icon:[UIApplicationShortcutIcon iconWithType: UIApplicationShortcutIconTypeTask]
                                                         userInfo:nil];
    [shortcutItems addObject:shortcutItem];
    
    for (NSString *dateText in self.segmentsTextArray) {
        UIApplicationShortcutItem * shortcutItem;
        shortcutItem =[[UIApplicationShortcutItem alloc] initWithType:@"Schedule"
                                                       localizedTitle:dateText
                                                    localizedSubtitle:@"議程"
                                                                 icon:[UIApplicationShortcutIcon iconWithType: UIApplicationShortcutIconTypeDate]
                                                             userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                        self.segmentsTextArray, @"segmentsTextArray",
                                                                        self.program_date, @"program_date",
                                                                        nil]];
        [shortcutItems addObject:shortcutItem];
    }
    
    [UIApplication sharedApplication].shortcutItems = shortcutItems;
}

-(void)setSegmentedAndTableWithText:(NSString *)selectedSegmentText{
    if ([self.segmentsTextArray count] == 0) {
        NSObject *scheduleDataObj = [[NSUserDefaults standardUserDefaults] objectForKey:@"ScheduleData"];
        if (scheduleDataObj) {
            NSDictionary *scheduleDataDict = (NSDictionary*)scheduleDataObj;
            self.segmentsTextArray = [scheduleDataDict objectForKey:@"segmentsTextArray"];
            self.program_date = [scheduleDataDict objectForKey:@"program_date"];
            
            [self.segmentedControl resetAllSegments:self.segmentsTextArray];
        }
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ScheduleData"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    NSInteger segmentsIndex = [self.segmentsTextArray indexOfObject:selectedSegmentText];
    [self setSegmentedAndTableWithIndex:segmentsIndex];
}

-(void)setSegmentedAndTableWithIndex:(NSInteger)selectedSegmentIndex{
    [self.segmentedControl setSelectedSegmentIndex:selectedSegmentIndex];
    NSString *selectedDate = [self.segmentsTextArray objectAtIndex:selectedSegmentIndex];
    [self.segmentedLabel setText:[NSString stringWithFormat:NSLocalizedString(@"ScheduleOfDate", nil), selectedDate]];

    static NSDateFormatter *formatter_full = nil;
    if (formatter_full == nil) {
        formatter_full = [NSDateFormatter new];
        [formatter_full setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
        [formatter_full setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    }
    
    static NSDateFormatter *formatter_HHmm = nil;
    if (formatter_HHmm == nil) {
        formatter_HHmm = [NSDateFormatter new];
        [formatter_HHmm setDateFormat:@"HH:mm"];
    }
    
    static NSDate *startTime;
    static NSDate *endTime;
    static NSString *startTime_str;
    static NSString *endTime_str;
    static NSString *timeKey;
    
    NSMutableDictionary *sectionDict = [NSMutableDictionary new];
    
    for (NSDictionary *program in [self.program_date objectForKey:selectedDate]) {
        startTime = [formatter_full dateFromString:[program objectForKey:@"starttime"]];
        endTime = [formatter_full dateFromString:[program objectForKey:@"endtime"]];
        startTime_str = [formatter_HHmm stringFromDate:startTime];
        endTime_str = [formatter_HHmm stringFromDate:endTime];
        timeKey = [NSString stringWithFormat:@"%@ ~ %@", startTime_str, endTime_str];
        
        NSMutableArray *tempArray = [sectionDict objectForKey:timeKey];
        if (tempArray == nil) {
            tempArray = [NSMutableArray new];
        }
        [tempArray addObject:program];
        [sectionDict setObject:tempArray forKey:timeKey];
    }
    
    self.program_date_section = sectionDict;
    
    [self.tableView reloadData];
}

-(void)checkScheduleDate {
    static NSDateFormatter *formatter_s = nil;
    if (formatter_s == nil) {
        formatter_s = [NSDateFormatter new];
        [formatter_s setDateFormat:@"MM/dd"];
    }
    
    if ([self.segmentedControl selectedSegmentIndex] == -1) {
        NSInteger segmentsIndex = 0;
        for (int index = 0; index < [self.segmentsTextArray count]; ++index) {
            if ([[formatter_s stringFromDate:[NSDate new]] isEqualToString:[self.segmentsTextArray objectAtIndex:index]]) {
                segmentsIndex = index;
            }
        }
        [self setSegmentedAndTableWithIndex:segmentsIndex];
    }
}

-(void)segmentedControlValueDidChange:(UISegmentedControl *)segment
{
    [self setSegmentedAndTableWithIndex:segment.selectedSegmentIndex];
//    [self.tableView setContentOffset:CGPointMake(0,-_topGuide) animated:YES];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

// Somewhere in your implementation file:

#pragma mark - Table view data source

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat progress = (scrollView.contentOffset.y + scrollView.contentInset.top) / (self.myBar.maximumBarHeight - self.myBar.minimumBarHeight);
    if (progress > 1) {
        progress = 1;
    }
    CGRect max_frame = MAX_TABLE_VIEW;
    CGRect min_frame = MIN_TABLE_VIEW;
    CGRect frame = CGRectMake(max_frame.origin.x + (min_frame.origin.x - max_frame.origin.x) * progress, max_frame.origin.y + (min_frame.origin.y - max_frame.origin.y) * progress, max_frame.size.width + (min_frame.size.width - max_frame.size.width) * progress, max_frame.size.height + (min_frame.size.height - max_frame.size.height) * progress);
    [self.tableView setFrame:frame];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.program_date_section count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *allKeys = [[self.program_date_section allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    return [[self.program_date_section objectForKey:[allKeys objectAtIndex:section]] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSArray *allKeys = [[self.program_date_section allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    return [allKeys objectAtIndex:section];;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *titleString = [self tableView:tableView titleForHeaderInSection:section];
    
    UIView *sectionView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.bounds.size.width, 28.0f)];
    [sectionView setBackgroundColor:[UIColor colorWithRed:61.0f/255.0f
                                                    green:152.0f/255.0f
                                                     blue:60.0f/255.0f
                                                    alpha:1.0f]];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectInset(sectionView.frame, 20.0f, 4.0f)];
    [titleLabel setFont:[UIFont systemFontOfSize:18.0f
                                          weight:UIFontWeightMedium]];
    [titleLabel setTextAlignment:NSTextAlignmentLeft];
    [titleLabel setTextColor:[UIColor whiteColor]];
    [titleLabel setBackgroundColor:[UIColor clearColor]];
    
    // set font Monospaced
    NSArray *monospacedSetting = @[@{UIFontFeatureTypeIdentifierKey: @(kNumberSpacingType),
                                     UIFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector)}];
    UIFontDescriptor *newDescriptor = [[titleLabel.font fontDescriptor] fontDescriptorByAddingAttributes:@{UIFontDescriptorFeatureSettingsAttribute: monospacedSetting}];
    // Size 0 to use previously set font size
    titleLabel.font = [UIFont fontWithDescriptor:newDescriptor size:0];
    
    [titleLabel setText:titleString];
    [sectionView addSubview:titleLabel];
    
    return sectionView;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Configure the cell...
    
    UITableViewCell *cell = [UITableViewCell new];
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    
    CGFloat cellContantWidth = self.view.frame.size.width - 40;
    CGFloat detailTextLabelWidth = 25;
    
    UILabel *textLabel = [UILabel new];
    [textLabel setFrame:CGRectMake(20, 12, cellContantWidth - detailTextLabelWidth - 20 , 20.3333)];
    
    UILabel *detailTextLabel = [UILabel new];
    [detailTextLabel setFrame:CGRectMake(cellContantWidth - detailTextLabelWidth, 12, 30, 20.3333)];
    [detailTextLabel setTextAlignment:NSTextAlignmentRight];
    [detailTextLabel setTextColor:[UIColor grayColor]];
    
    // set font Monospaced
    NSArray *monospacedSetting = @[@{UIFontFeatureTypeIdentifierKey: @(kNumberSpacingType),
                                     UIFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector)}];
    UIFontDescriptor *newDescriptor = [[detailTextLabel.font fontDescriptor] fontDescriptorByAddingAttributes:@{UIFontDescriptorFeatureSettingsAttribute: monospacedSetting}];
    // Size 0 to use previously set font size
    detailTextLabel.font = [UIFont fontWithDescriptor:newDescriptor size:0];
    
    [cell addSubview:textLabel];
    [cell addSubview:detailTextLabel];
    
    NSArray *allKeys = [[self.program_date_section allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSDictionary *program = [[self.program_date_section objectForKey:[allKeys objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
    
    [textLabel setText:[program objectForKey:@"subject"]];
    [detailTextLabel setText:[program objectForKey:@"room"]];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[self.tableView cellForRowAtIndexPath:indexPath] setSelected:NO
                                                    animated:YES];
    // TODO: display selected section detail informations
    
    NSArray *allKeys = [[self.program_date_section allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSDictionary *program = [[self.program_date_section objectForKey:[allKeys objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
    
    ProgramDetailViewController *detailViewController = [[ProgramDetailViewController alloc] initWithNibName:@"ProgramDetailViewController"
                                                                                                      bundle:[NSBundle mainBundle]
                                                                                                     Program:program];
    [self.navigationController pushViewController:detailViewController animated:YES];
}

/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */

/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
 } else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }
 }
 */

/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
 }
 */

/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */

@end
