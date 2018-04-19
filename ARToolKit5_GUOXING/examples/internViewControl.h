//
//  internViewControl.h
//  ARToolKit5iOS
//
//  Created by GUO Xing on 13/4/2018.
//

#import <UIKit/UIKit.h>
#import "SecViewController.h"
@interface internViewControl : UIViewController <UIPageViewControllerDataSource>

@property (strong, nonatomic) UIPageViewController *pageController;

@end
