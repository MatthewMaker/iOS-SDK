//
//  FMViewController.m
//  sdktest
//
//  Created by James Anthony on 3/7/13.
//  Copyright (c) 2013 Feed Media, Inc. All rights reserved.
//

#import "FMViewController.h"
#import "FMStationPickerViewController.h"
#import "FMProgressView.h"

#define kFMClientToken @"e518c7bb995c28ea12deb8ddc9b6458c41005f56"
#define kFMClientSecret @"512cac1423f76a4b25235fa0afb092013b68f7d8"
#define kFMPlacementId @"10002"

#define kFMProgressBarUpdateTimeInterval 0.5
#define kFMProgressBarHeight 5.0f

@interface FMViewController () {
    NSTimer *_progressTimer;
}

@property IBOutlet UILabel *currentStationLabel;
@property IBOutlet UIView *playerContainer;
@property FMProgressView *progressView;
@property IBOutlet UILabel *songLabel;
@property IBOutlet UILabel *artistLabel;
@property IBOutlet UIButton *playButton;
@property IBOutlet UIButton *skipButton;
@property UIActivityIndicatorView *playButtonSpinner;

- (IBAction)selectStation:(id)sender;
- (IBAction)play:(id)sender;
- (IBAction)skip:(id)sender;
- (IBAction)setVolume:(id)sender;

@end

@implementation FMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Feed Media SDK Demo";
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:nil
                                                                            action:nil];

    self.progressView = [[FMProgressView alloc] initWithFrame:CGRectMake(0,
                                                                         self.playerContainer.bounds.size.height - kFMProgressBarHeight,
                                                                         self.playerContainer.bounds.size.width,
                                                                         kFMProgressBarHeight)];
    self.progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

    [self.playerContainer addSubview:self.progressView];
    
    [FMAudioPlayer setClientToken:kFMClientToken
                           secret:kFMClientSecret];
    self.feedPlayer = [FMAudioPlayer sharedPlayer];
    [self.feedPlayer setPlacement:kFMPlacementId];
    FMLogDebug(@"Set placement: %@", self.feedPlayer.activePlacementId);

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stationUpdated:) name:FMAudioPlayerActiveStationDidChangeNotification object:self.feedPlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(songUpdated:) name:FMAudioPlayerCurrentItemDidChangeNotification object:self.feedPlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerUpdated:) name:FMAudioPlayerPlaybackStateDidChangeNotification object:self.feedPlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(skipFailed:) name:FMAudioPlayerSkipFailedNotification object:self.feedPlayer];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self cancelProgressTimer];
}

- (void)stationUpdated:(NSNotification *)notification {
    self.currentStationLabel.text = self.feedPlayer.activeStation.name;
}

- (void)songUpdated:(NSNotification *)notification {
    [self updateLabels];
}

- (void)selectStation:(id)sender {
    [self.navigationController pushViewController:[[FMStationPickerViewController alloc] init] animated:YES];
}

- (void)playerUpdated:(NSNotification *)notification {
    FMAudioPlayerPlaybackState newState = self.feedPlayer.playbackState;
    FMLogDebug(@"Got playback state: %i", newState);
    switch(newState) {
        case FMAudioPlayerPlaybackStateWaitingForItem:
            [self showPlayButtonSpinner];
            [self.skipButton setEnabled:NO];
            break;
        case FMAudioPlayerPlaybackStateReadyToPlay:
        case FMAudioPlayerPlaybackStatePaused:
            [self hidePlayButtonSpinner];
            [self.skipButton setEnabled:YES];
            [self.playButton setEnabled:YES];
            [self.playButton setImage:[UIImage imageNamed:@"play.png"] forState:UIControlStateNormal];
            [self cancelProgressTimer];
            break;
        case FMAudioPlayerPlaybackStatePlaying:
            [self hidePlayButtonSpinner];
            [self.playButton setImage:[UIImage imageNamed:@"pause.png"] forState:UIControlStateNormal];
            [self.playButton setEnabled:YES];
            [self.skipButton setEnabled:YES];
            [self startProgressTimer];
            break;
        case FMAudioPlayerPlaybackStateStalled:
            [self showPlayButtonSpinner];
            [self.playButton setEnabled:NO];
            [self.skipButton setEnabled:YES];
            break;
        case FMAudioPlayerPlaybackStateRequestingSkip:
            [self showPlayButtonSpinner];
            [self.playButton setEnabled:NO];
            [self.skipButton setEnabled:NO];
            break;
        case FMAudioPlayerPlaybackStateComplete:
            [self.playButton setEnabled:NO];
            [self.skipButton setEnabled:NO];
            [self cancelProgressTimer];
            [self.progressView setProgress:0.0];
            break;
        default:
            break;
    };
}

- (void)updateLabels {
    self.songLabel.text = self.feedPlayer.currentItem.name;
    self.artistLabel.text = self.feedPlayer.currentItem.artist;
}

- (void)setVolume:(id)sender {
    assert([sender isKindOfClass:[UISlider class]]);
    self.feedPlayer.mixVolume = [(UISlider *)sender value];
}

#pragma mark - Player Button States


- (void)play:(id)sender {
    if(self.feedPlayer.playbackState == FMAudioPlayerPlaybackStatePlaying) {
        [self.feedPlayer pause];
    } else {
        [self.feedPlayer play];
    }
}

- (void)skip:(id)sender {
    [self.feedPlayer skip];
}

- (void)skipFailed:(NSNotification *)notification {
    NSError *error = notification.userInfo[FMAudioPlayerSkipFailureErrorKey];
    if([[error domain] isEqualToString:FMAPIErrorDomain] && [error code] == FMErrorCodeSkipLimitExceeded) {
        UIAlertView *noSkipAlert = [[UIAlertView alloc] initWithTitle:@"No More Skips" message:@"Sorry, you‘ve reached your skip limit for this station. Skips will replenish over time." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [noSkipAlert show];
    }
}

- (void)showPlayButtonSpinner {
    if([self.playButtonSpinner superview]) return;

    self.playButtonSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.playButtonSpinner.frame = self.playButton.frame;
    [[self.playButton superview] addSubview:self.playButtonSpinner];
    [self.playButton setHidden:YES];
    [self.playButtonSpinner startAnimating];
}

- (void)hidePlayButtonSpinner {
    [self.playButtonSpinner stopAnimating];
    [self.playButtonSpinner removeFromSuperview];
    self.playButtonSpinner = nil;
    [self.playButton setHidden:NO];
}

#pragma mark - Progress Bar
- (void)cancelProgressTimer {
    [_progressTimer invalidate];
    _progressTimer = nil;
}

- (void)startProgressTimer {
    [_progressTimer invalidate];
    _progressTimer = [NSTimer scheduledTimerWithTimeInterval:kFMProgressBarUpdateTimeInterval
                                                     target:self
                                                   selector:@selector(updateProgress:)
                                                   userInfo:nil
                                                    repeats:YES];
}

- (void)updateProgress:(NSTimer *)timer {
    NSTimeInterval duration = self.feedPlayer.currentItemDuration;
    if(duration > 0) {
        [self.progressView setProgress:(self.feedPlayer.currentPlaybackTime / duration)
                 withAnimationDuration:kFMProgressBarUpdateTimeInterval];
    }
    else {
        self.progressView.progress = 0.0;
    }
}

@end

#undef kFMProgressBarUpdateTimeInterval
#undef kFMProgressBarHeight
#undef kFMClientToken
#undef kFMClientSecret
#undef kFMPlacementId
