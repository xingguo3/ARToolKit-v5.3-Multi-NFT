//
//  internViewControl.m
//  ARToolKit5iOS
//
//  Created by GUO Xing on 13/4/2018.
//

#import "internViewControl.h"
@interface internViewControl ()

@end

@implementation internViewControl

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.pageController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
    
    self.pageController.dataSource = self;
    [[self.pageController view] setFrame:[[self view] bounds]];
    
    SecViewController *initialViewController = [self viewControllerAtIndex:0];
    
    NSArray *viewControllers = [NSArray arrayWithObject:initialViewController];
    
    [self.pageController setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
    
    [self addChildViewController:self.pageController];
    [[self view] addSubview:[self.pageController view]];
    [self.pageController didMoveToParentViewController:self];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    
    NSUInteger index = [(SecViewController *)viewController index];
    
    if (index == 0) {
        return nil;
    }
    
    index--;
    
    return [self viewControllerAtIndex:index];
    
}

-(void) startApp {
//    ARViewController *svc = [[ARViewController alloc] initWithNibName:nil bundle:nil];
//    [self presentModalViewController:svc animated:YES ];
////    [svc start];
//    [svc release];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    
    NSUInteger index = [(SecViewController *)viewController index];
    
    if (index > 6) {
        [self.view.window.rootViewController dismissViewControllerAnimated:YES completion:nil];
        return nil;
    }
    index++;
    
   
    
    return [self viewControllerAtIndex:index];
    
}

- (SecViewController *)viewControllerAtIndex:(NSUInteger)index {
    
    SecViewController *childViewController = [[SecViewController alloc] initWithNibName:@"SecViewController" bundle:nil];
    childViewController.index = index;
    
    return childViewController;
    
}


- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController {
    // The number of items reflected in the page indicator.
    return 2;
}

- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController {
    // The selected item reflected in the page indicator.
    return 0;
}




@end
