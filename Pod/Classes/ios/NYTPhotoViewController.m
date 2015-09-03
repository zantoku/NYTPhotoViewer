//
//  NYTPhotoViewController.m
//  Pods
//
//  Created by Brian Capps on 2/11/15.
//
//

#import "NYTPhotoViewController.h"
#import "NYTPhoto.h"
#import "NYTScalingImageView.h"
#import <MediaPlayer/MediaPlayer.h>

NSString * const NYTPhotoViewControllerPhotoImageUpdatedNotification = @"NYTPhotoViewControllerPhotoImageUpdatedNotification";

@interface NYTPhotoViewController () <UIScrollViewDelegate>

@property (nonatomic) id <NYTPhoto> photo;

@property (nonatomic) NYTScalingImageView *scalingImageView;
@property (nonatomic) UIView *loadingView;
@property (nonatomic) NSNotificationCenter *notificationCenter;
@property (nonatomic) UITapGestureRecognizer *doubleTapGestureRecognizer;
@property (nonatomic) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (nonatomic) UIButton *playButton;
@property (nonatomic) MPMoviePlayerController * moviePlayer;

@end

@implementation NYTPhotoViewController

#pragma mark - NSObject

- (void)dealloc {
    _scalingImageView.delegate = nil;
    
    [_notificationCenter removeObserver:self];
}

#pragma mark - UIViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    return [self initWithPhoto:nil loadingView:nil playButton:nil notificationCenter:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.notificationCenter addObserver:self selector:@selector(photoImageUpdatedWithNotification:) name:NYTPhotoViewControllerPhotoImageUpdatedNotification object:nil];
    
    self.scalingImageView.frame = self.view.bounds;
    [self.view addSubview:self.scalingImageView];
    
    [self.view addSubview:self.loadingView];
    [self.loadingView sizeToFit];
    
    [self.view addGestureRecognizer:self.doubleTapGestureRecognizer];
    [self.view addGestureRecognizer:self.longPressGestureRecognizer];
    
    [self.view addSubview:self.playButton];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    self.scalingImageView.frame = self.view.bounds;
    
    [self.loadingView sizeToFit];
    self.loadingView.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
    
    if (self.photo.movieURL) {
        self.playButton.hidden = false;
        self.loadingView.hidden = true;
    } else {
        self.playButton.hidden = true;
        self.loadingView.hidden = false;
    }
    self.playButton.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.moviePlayer) {
        [self.moviePlayer stop];
        [self.moviePlayer.view removeFromSuperview];
        self.scalingImageView.hidden = false;
        self.moviePlayer = nil;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    if ([self.delegate respondsToSelector:@selector(photoViewController:didShowPhoto:)]) {
        [self.delegate photoViewController:self didShowPhoto:self.photo];
    }
}


#pragma mark - NYTPhotoViewController

- (instancetype)initWithPhoto:(id <NYTPhoto>)photo loadingView:(UIView *)loadingView playButton:(UIButton *)playButton notificationCenter:(NSNotificationCenter *)notificationCenter {
    self = [super initWithNibName:nil bundle:nil];
    
    if (self) {
        _photo = photo;
        
        UIImage *photoImage = photo.image ?: photo.placeholderImage;
        
        _scalingImageView = [[NYTScalingImageView alloc] initWithImage:photoImage frame:CGRectZero];
        _scalingImageView.delegate = self;
        
        if (!photo.image) {
            [self setupLoadingView:loadingView];
        }
        
        if (photo.movieURL) {
            [self setupPlayButton:playButton];
        }
        
        _notificationCenter = notificationCenter;
        
        [self setupGestureRecognizers];
    }
    
    return self;
}

- (void)setupLoadingView:(UIView *)loadingView {
    self.loadingView = loadingView;
    if (!loadingView) {
        UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [activityIndicator startAnimating];
        self.loadingView = activityIndicator;
    }
}

- (void)setupPlayButton:(UIButton *)playButton {
    if (!playButton) {
        playButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 64, 64)];
        [playButton setTitle:@"▶\U0000FE0E" forState:UIControlStateNormal];
        [playButton.titleLabel setFont:[UIFont systemFontOfSize:40]];
        [playButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [playButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateHighlighted];
        [playButton setTitleEdgeInsets:UIEdgeInsetsMake(0, 4, 0, 0)];
        [playButton.layer setCornerRadius:32];
        [playButton.layer setBorderColor:[[UIColor whiteColor] CGColor]];
        [playButton.layer setBorderWidth:2];
        [playButton setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.5]];
    } else {
        [playButton sizeToFit];
    }
    [playButton addTarget:self action:@selector(playMovie:) forControlEvents:UIControlEventTouchUpInside];
    self.playButton = playButton;
}

- (void)photoImageUpdatedWithNotification:(NSNotification *)notification {
    id <NYTPhoto> photo = notification.object;
    if ([photo conformsToProtocol:@protocol(NYTPhoto)] && [photo isEqual:self.photo]) {
        [self updateView];
    }
}

- (void)updateView {
    UIImage *image = self.photo.image;
    [self.scalingImageView updateImage:image];

    if (self.photo.movieURL) {
        self.loadingView.hidden = true;
        self.playButton.hidden = false;
    } else {
        self.loadingView.hidden = false;
        self.playButton.hidden = true;
    }
    
    if (image) {
        self.loadingView.hidden = true;
    }
}

#pragma mark - Movie playback

- (void)play {
    [self playMovie:nil];
}

- (void)playMovie:(id)sender {
    if (!self.moviePlayer && self.photo.movieURL) {
        self.moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:self.photo.movieURL];
        self.moviePlayer.shouldAutoplay = YES;
        self.moviePlayer.controlStyle = MPMediaTypeAnyVideo;
        UIView * videoView = self.moviePlayer.view;
        
        self.scalingImageView.hidden = true;
        [self.view addSubview:videoView];
        videoView.frame = self.view.bounds;
        
         [self.moviePlayer prepareToPlay];
        [self.moviePlayer play];
    }
}

#pragma mark - Gesture Recognizers

- (void)setupGestureRecognizers {
    self.doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didDoubleTapWithGestureRecognizer:)];
    self.doubleTapGestureRecognizer.numberOfTapsRequired = 2;
    
    self.longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPressWithGestureRecognizer:)];
}

- (void)didDoubleTapWithGestureRecognizer:(UITapGestureRecognizer *)recognizer {
    CGPoint pointInView = [recognizer locationInView:self.scalingImageView.imageView];
    
    CGFloat newZoomScale = self.scalingImageView.maximumZoomScale;
    
    if (self.scalingImageView.zoomScale >= self.scalingImageView.maximumZoomScale) {
        newZoomScale = self.scalingImageView.minimumZoomScale;
    }
    
    CGSize scrollViewSize = self.scalingImageView.bounds.size;
    
    CGFloat width = scrollViewSize.width / newZoomScale;
    CGFloat height = scrollViewSize.height / newZoomScale;
    CGFloat originX = pointInView.x - (width / 2.0);
    CGFloat originY = pointInView.y - (height / 2.0);
    
    CGRect rectToZoomTo = CGRectMake(originX, originY, width, height);
    
    [self.scalingImageView zoomToRect:rectToZoomTo animated:YES];
}

- (void)didLongPressWithGestureRecognizer:(UILongPressGestureRecognizer *)recognizer {
    if ([self.delegate respondsToSelector:@selector(photoViewController:didLongPressWithGestureRecognizer:)]) {
        if (recognizer.state == UIGestureRecognizerStateBegan) {
            [self.delegate photoViewController:self didLongPressWithGestureRecognizer:recognizer];
        }
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.scalingImageView.imageView;
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
    scrollView.panGestureRecognizer.enabled = YES;
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    // There is a bug, especially prevalent on iPhone 6 Plus, that causes zooming to render all other gesture recognizers ineffective.
    // This bug is fixed by disabling the pan gesture recognizer of the scroll view when it is not needed.
    if (scrollView.zoomScale == scrollView.minimumZoomScale) {
        scrollView.panGestureRecognizer.enabled = NO;
    }
}

@end
