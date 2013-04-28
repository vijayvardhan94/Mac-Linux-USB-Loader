//
//  CTAppDelegate.m
//  Compatibility Tester
//
//  Created by SevenBits on 4/18/13.
//
//

#import "CTAppDelegate.h"

@implementation CTAppDelegate

@synthesize window;
@synthesize spinner;
@synthesize textView;

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    [spinner startAnimation:self];
    [self performSelector:@selector(performSystemCheck)];
}

- (void)performSystemCheck {
    NSTextStorage *storage = [textView textStorage];
    [storage beginEditing];
    
    size_t len = 0;
    sysctlbyname("hw.model", NULL, &len, NULL, 0);
    
    if (len)
    {
        char *model = malloc(len*sizeof(char));
        sysctlbyname("hw.model", model, &len, NULL, 0);
        NSString *model_ns = [NSString stringWithUTF8String:model];
        free(model);
        
        NSAttributedString *string = [[NSAttributedString alloc]
                                      initWithString:[NSString stringWithFormat:@"Computer Model: %@\n", model_ns]];
        [storage appendAttributedString:string];
    }
    
    [self findGraphicsCard:storage];
    
    [storage endEditing];
    [spinner stopAnimation:self];
}

- (void)findGraphicsCard:(NSTextStorage*)storage {
    // Check the PCI devices for video cards.
    CFMutableDictionaryRef match_dictionary = IOServiceMatching("IOPCIDevice");
    
    // Create a iterator to go through the found devices.
    io_iterator_t entry_iterator;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault,
                                     match_dictionary,
                                     &entry_iterator) == kIOReturnSuccess) {
        // Actually iterate through the found devices.
        io_registry_entry_t serviceObject;
        while ((serviceObject = IOIteratorNext(entry_iterator))) {
            // Put this services object into a dictionary object.
            CFMutableDictionaryRef serviceDictionary;
            if (IORegistryEntryCreateCFProperties(serviceObject,
                                                  &serviceDictionary,
                                                  kCFAllocatorDefault,
                                                  kNilOptions) != kIOReturnSuccess) {
                // Failed to create a service dictionary, release and go on.
                IOObjectRelease(serviceObject);
                continue;
            }
            
            // If this is a GPU listing, it will have a "model" key
            // that points to a CFDataRef.
            const void *model = CFDictionaryGetValue(serviceDictionary, @"model");
            if (model != nil) {
                if (CFGetTypeID(model) == CFDataGetTypeID()) {
                    // Create a string from the CFDataRef.
                    NSString *s = [[NSString alloc] initWithData:(__bridge NSData *)model encoding:NSASCIIStringEncoding];
#ifdef DEBUG
                    NSLog(@"Found GPU: %@", s);
#endif
                    
                    // Append this GPU to the list of detected hardware.
                    NSAttributedString *string = [[NSAttributedString alloc]
                                                  initWithString:[NSString stringWithFormat:@"Graphics: %@\n", s]];
                    [storage appendAttributedString:string];
                }
            }
            
            // Release the dictionary created by IORegistryEntryCreateCFProperties.
            CFRelease(serviceDictionary);
            
            // Release the serviceObject returned by IOIteratorNext.
            IOObjectRelease(serviceObject);
        }
        
        // Release the entry_iterator created by IOServiceGetMatchingServices.
        IOObjectRelease(entry_iterator);
    }
}

@end