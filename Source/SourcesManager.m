//
//  SourcesManager.m
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

#import "CallbackSource.h"
#import "LoopingSource.h"
#import "Rule.h"
#import "Source.h"
#import "SourcesManager.h"
#import "SynthesizeSingleton.h"
#import <objc/objc-class.h>

@interface SourcesManager (Private)

- (void) createSources;
- (BOOL) isClass: (Class) aClass superclassOfClass: (Class) subClass;

@end

@implementation SourcesManager

SYNTHESIZE_SINGLETON_FOR_CLASS(SourcesManager);

- (id) init {
	ZAssert(!sharedSourcesManager, @"This is a singleton, use %@.shared%@", NSStringFromClass(self.class), NSStringFromClass(self.class));
	
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_sources = [NSMutableDictionary new];
	m_sourceTypes = [NSMutableArray new];
	m_sourcesCreated = NO;
	
	return self;
}

- (void) dealloc {
	[m_sources release];
	[m_sourceTypes release];
	
	[super dealloc];
}

#pragma mark - Source types

- (void) registerSourceType: (Class) type {
	// sanity check
	if ([self isClass: CallbackSource.class superclassOfClass: type])
		ZAssert([type conformsToProtocol: @protocol(CallbackSourceProtocol)], @"Unsupported Source type");
	else if ([self isClass: LoopingSource.class superclassOfClass: type])
		ZAssert([type conformsToProtocol: @protocol(LoopingSourceProtocol)], @"Unsupported Source type");
	else
		ZAssert([type conformsToProtocol: @protocol(SourceProtocol)], @"Unsupported Source type");
	
	// store it
	DLog(@"Registererd type: %@", NSStringFromClass(type));
	[m_sourceTypes addObject: type];
}

- (void) createSources {
	Source *source = nil;
	
	// create an instance of each source type
	@synchronized(m_sources) {
		for (Class type in m_sourceTypes) {
			source = [[type new] autorelease];
			[m_sources setObject: source forKey: source.name];
		}
	}
	
	m_sourcesCreated = YES;
}

#pragma mark - Other functions

- (Source *) getSource: (NSString *) name {
	@synchronized(m_sources) {
		return [m_sources objectForKey: name];
	}
}

- (void) removeSource: (NSString *) name {
	@synchronized(m_sources) {
		[m_sources removeObjectForKey: name];
	}
}

- (BOOL) isClass: (Class) aClass superclassOfClass: (Class) subClass {
	Class class = class_getSuperclass(subClass);
	
	while (class != nil) {
		if (class == aClass)
			return YES;
		class = class_getSuperclass(class);
	}
	
	return NO;
}

#pragma mark - Rules registration

- (Source *) registerRule: (Rule *) rule toSource: (NSString *) source {
	if (!m_sourcesCreated)
		[self createSources];
	
	@synchronized(m_sources) {
		// find it
		Source *sourceInstance = [self getSource: source];
		ZAssert(sourceInstance != nil, @"Unknown source: %@", source);
		
		// register
		[sourceInstance addObserver: rule];
		
		return sourceInstance;
	}
}

- (void) unRegisterRule: (Rule *) rule fromSource: (NSString *) source {
	if (!m_sourcesCreated)
		[self createSources];
	
	@synchronized(m_sources) {
		// find it
		Source *sourceInstance = [self getSource: source];
		ZAssert(sourceInstance != nil, @"Unknown source: %@", source);
		
		// unregister
		[sourceInstance removeObserver: rule];
	}
}

@end