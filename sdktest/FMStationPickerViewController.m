//
//  FMStationPickerViewController.m
//  sdktest
//
//  Created by James Anthony on 4/1/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import "FMStationPickerViewController.h"
#import "FMAudioPlayer.h"

#define kFMStationPickerCellIdentifier @"kFMStationPickerCellIdentifier"

@interface FMStationPickerViewController () 

@property (nonatomic) NSArray *stations;
@property (nonatomic) UITableViewCell *selectedCell;

@end

@implementation FMStationPickerViewController

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"Select Station";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [[FMAudioPlayer sharedPlayer] requestStationsForPlacement:nil
                                                  withSuccess:
     ^(NSArray *stations) {
         self.stations = stations;
     }
                                                      failure:
     ^(NSError *error) {
        [self stationRequestFailed:error];
    }];
}

- (void)setStations:(NSArray *)stations {
    _stations = stations;
    [self.tableView reloadData];
}

- (void)stationRequestFailed:(NSError *)error {
    self.stations = nil;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to Retreive Stations" message:@"Station request failed." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if(section == 0) {
        return [self.stations count];
    }
    else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kFMStationPickerCellIdentifier];
    if(cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kFMStationPickerCellIdentifier];
    }
    
    FMStation *station = self.stations[indexPath.row];
    cell.textLabel.text = station.name;
    cell.detailTextLabel.text = station.identifier;
    if([station isEqual:[FMAudioPlayer sharedPlayer].activeStation]) {
        [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        self.selectedCell = cell;
    }
    else {
        [cell setAccessoryType:UITableViewCellAccessoryNone];
    }

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[FMAudioPlayer sharedPlayer] setStation:self.stations[indexPath.row]];
    
    [self.selectedCell setAccessoryType:UITableViewCellAccessoryNone];
    self.selectedCell = [self.tableView cellForRowAtIndexPath:indexPath];
    [self.selectedCell setAccessoryType:UITableViewCellAccessoryCheckmark];

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

#undef kFMStationPickerCellIdentifier
